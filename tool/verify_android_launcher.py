"""Verify compiled Android launcher identity and adaptive resources.

Reads APK binary XML and its resource table, including modern compact entries,
so activity aliases are checked even when aapt badging omits them. Uses only
the standard library and never reads private signing material.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import xml.etree.ElementTree as ET
import zipfile


ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
FOREGROUND_SOURCE = (
    "app/android/app/src/main/res/drawable/gooes_launcher_foreground.xml"
)


def u16(data, offset):
    return struct.unpack_from("<H", data, offset)[0]


def u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def chunks(data, start, end):
    offset = start
    while offset < end:
        kind, header_size, size = struct.unpack_from("<HHI", data, offset)
        assert header_size >= 8 and size >= header_size and offset + size <= end
        yield offset, kind, header_size, size
        offset += size
    assert offset == end


def pool(data, offset):
    count = u32(data, offset + 8)
    flags = u32(data, offset + 16)
    strings_start = offset + u32(data, offset + 20)
    header_size = u16(data, offset + 2)
    result = []
    for index in range(count):
        position = strings_start + u32(data, offset + header_size + 4 * index)
        if flags & 0x100:
            # UTF-8 pools store both the UTF-16 character count and byte count.
            length = data[position]
            position += 1
            if length & 0x80:
                position += 1
            length = data[position]
            position += 1
            if length & 0x80:
                length = ((length & 0x7F) << 8) | data[position]
                position += 1
            result.append(data[position:position + length].decode("utf-8"))
        else:
            length = u16(data, position)
            position += 2
            if length & 0x8000:
                length = ((length & 0x7FFF) << 16) | u16(data, position)
                position += 2
            result.append(data[position:position + length * 2].decode("utf-16le"))
    return result


def typed_value(kind, data, strings):
    if kind == 3:
        return strings[data]
    if kind == 1:
        return {"ref": data}
    if kind == 4:
        return struct.unpack("<f", struct.pack("<I", data))[0]
    if kind == 18:
        return bool(data)
    return {"type": kind, "data": data}


def value(data, offset, strings):
    return typed_value(data[offset + 3], u32(data, offset + 4), strings)


def table_entry(data, offset, keys, strings):
    """Decode full and FLAG_COMPACT simple entries, skipping complex bags.

    Android ResourceTypes.h stores compact keys in the first uint16, the value
    type in the high flags byte, and the value directly at offset + 4.
    """
    flags = u16(data, offset + 2)
    if flags & 1:
        assert not flags & 8, "An entry cannot be both complex and compact"
        return None
    if flags & 8:
        key = keys[u16(data, offset)]
        decoded = typed_value(flags >> 8, u32(data, offset + 4), strings)
    else:
        key = keys[u32(data, offset + 4)]
        decoded = value(data, offset + u16(data, offset), strings)
    return key, decoded


def axml(data):
    assert u16(data, 0) == 3, "Expected Android binary XML"
    strings = []
    nodes = []
    depth = 0
    for offset, kind, _, _ in chunks(data, u16(data, 2), u32(data, 4)):
        if kind == 1:
            strings = pool(data, offset)
        elif kind == 0x102:
            extension = offset + 16
            name = strings[u32(data, extension + 4)]
            start = u16(data, extension + 8)
            step = u16(data, extension + 10)
            count = u16(data, extension + 12)
            attributes = {}
            for index in range(count):
                attribute = extension + start + step * index
                key = strings[u32(data, attribute + 4)]
                raw = u32(data, attribute + 8)
                attributes[key] = (
                    strings[raw] if raw != 0xFFFFFFFF
                    else value(data, attribute + 12, strings)
                )
            nodes.append({"name": name, "depth": depth, "attrs": attributes})
            depth += 1
        elif kind == 0x103:
            depth -= 1
    return nodes


def resources(data):
    strings = []
    entries = {}
    for offset, kind, header_size, size in chunks(
        data, u16(data, 2), u32(data, 4)
    ):
        if kind == 1:
            strings = pool(data, offset)
        if kind != 0x200:
            continue
        package = u32(data, offset + 8)
        types = pool(data, offset + u32(data, offset + 268))
        keys = pool(data, offset + u32(data, offset + 276))
        type_offset = u32(data, offset + 284) if header_size >= 288 else 0
        for type_start, chunk_kind, type_header, _ in chunks(
            data, offset + header_size, offset + size
        ):
            if chunk_kind != 0x201:
                continue
            type_id = data[type_start + 8]
            flags = data[type_start + 9]
            count = u32(data, type_start + 12)
            start = type_start + u32(data, type_start + 16)
            config_size = u32(data, type_start + 20)
            sdk = u16(data, type_start + 44) if config_size >= 28 else 0
            indexes = []
            for index in range(count):
                if flags & 1:  # Sparse index/offset pairs.
                    position = type_start + type_header + 4 * index
                    indexes.append(
                        (u16(data, position), u16(data, position + 2) * 4)
                    )
                elif flags & 2:  # Dense 16-bit offsets, divided by four.
                    relative = u16(data, type_start + type_header + 2 * index)
                    if relative != 0xFFFF:
                        indexes.append((index, relative * 4))
                else:
                    relative = u32(data, type_start + type_header + 4 * index)
                    if relative != 0xFFFFFFFF:
                        indexes.append((index, relative))
            for index, relative in indexes:
                decoded = table_entry(data, start + relative, keys, strings)
                if decoded is None:
                    continue
                key, entry_value = decoded
                resource_id = (
                    (package << 24) | ((type_id + type_offset) << 16) | index
                )
                entries.setdefault(resource_id, []).append({
                    "type": types[type_id - 1],
                    "name": key,
                    "sdk": sdk,
                    "value": entry_value,
                })
    return entries


def verify(apk, source_root):
    source = ET.parse(source_root / FOREGROUND_SOURCE).getroot()
    source_group = source.find("group")
    source_paths = source_group.findall("path")
    with zipfile.ZipFile(apk) as archive:
        nodes = axml(archive.read("AndroidManifest.xml"))
        resource_table = resources(archive.read("resources.arsc"))

        def choices(resource):
            if isinstance(resource, dict) and "ref" in resource:
                return resource_table[resource["ref"]]
            return [{"value": resource}]

        def label(resource):
            return sorted({str(item["value"]) for item in choices(resource)})

        application = next(node for node in nodes if node["name"] == "application")
        aliases = [node for node in nodes if node["name"] == "activity-alias"]
        manifest = next(node for node in nodes if node["name"] == "manifest")
        assert manifest["attrs"]["package"] == "pro.dotslash.ava.fork"
        assert label(application["attrs"]["label"]) == ["gooes SteamKit"]
        assert len(aliases) == 2
        assert {
            alias["attrs"]["name"].rsplit(".", 1)[-1] for alias in aliases
        } == {"LauncherNeon", "LauncherPixel"}
        checked = []
        for alias in aliases:
            attributes = alias["attrs"]
            name = attributes["name"].rsplit(".", 1)[-1]
            alias_label = label(
                attributes.get("label", application["attrs"]["label"])
            )
            assert alias_label == ["gooesteamkit"], (
                f"{name}: expected launcher label gooesteamkit, got {alias_label}"
            )
            assert attributes["enabled"] == (name == "LauncherNeon")
            options = choices(attributes["icon"])
            legacy = [item for item in options if item["value"].endswith(".png")]
            adaptive = [
                item for item in options
                if item["value"].endswith(".xml") and item["sdk"] == 26
            ]
            assert len(legacy) == 5 and len(adaptive) == 1, options
            content = archive.read(adaptive[0]["value"])
            adaptive_xml = axml(content)
            assert adaptive_xml[0]["name"] == "adaptive-icon"
            foreground = next(
                item for item in adaptive_xml if item["name"] == "foreground"
            )["attrs"]["drawable"]
            background = next(
                item for item in adaptive_xml if item["name"] == "background"
            )["attrs"]["drawable"]
            backgrounds = choices(background)
            assert all(
                item["name"] == "gooes_launcher_background"
                and item["value"]["data"] == 0xFF202020
                for item in backgrounds
            ), backgrounds
            foregrounds = choices(foreground)
            assert len(foregrounds) == 1
            assert foregrounds[0]["name"] == "gooes_launcher_foreground"
            vector_content = archive.read(foregrounds[0]["value"])
            vector = axml(vector_content)
            assert vector[0]["name"] == "vector"
            assert vector[0]["attrs"]["viewportWidth"] == 108
            assert vector[0]["attrs"]["viewportHeight"] == 108
            compiled_group = next(
                item for item in vector if item["name"] == "group"
            )["attrs"]
            for key in ("scaleX", "scaleY", "translateX", "translateY"):
                expected = float(source_group.attrib[ANDROID_NS + key])
                assert abs(compiled_group[key] - expected) < 1e-5
            paths = [item for item in vector if item["name"] == "path"]
            assert len(paths) == len(source_paths) == 9
            for path, expected in zip(paths, source_paths):
                assert path["attrs"]["pathData"] == expected.attrib[
                    ANDROID_NS + "pathData"
                ]
                assert path["attrs"]["fillColor"]["data"] == int(
                    expected.attrib[ANDROID_NS + "fillColor"][1:], 16
                )
            checked.append({
                "alias": attributes["name"],
                "enabled": attributes["enabled"],
                "label": alias_label[0],
                "legacy_density_count": len(legacy),
                "adaptive_sdk": 26,
                "adaptive_apk_path": adaptive[0]["value"],
                "adaptive_sha256": hashlib.sha256(content).hexdigest(),
                "foreground_resource": foregrounds[0]["name"],
                "foreground_apk_path": foregrounds[0]["value"],
                "foreground_sha256": hashlib.sha256(vector_content).hexdigest(),
                "compiled_paths_match_source": True,
                "vector_path_count": len(paths),
                "background": "#FF202020",
                "viewport_dp": [108, 108],
            })
        assert checked[0]["foreground_sha256"] == checked[1]["foreground_sha256"]
        assert application["attrs"]["roundIcon"] == application["attrs"]["icon"]
        primary_alias = next(
            alias for alias in aliases
            if alias["attrs"]["name"].endswith(".LauncherNeon")
        )
        assert application["attrs"]["icon"] == primary_alias["attrs"]["icon"]
        with apk.open("rb") as stream:
            apk_sha256 = hashlib.file_digest(stream, "sha256").hexdigest()
        return {
            "apk_sha256": apk_sha256,
            "package": manifest["attrs"]["package"],
            "application_label": label(application["attrs"]["label"])[0],
            "round_icon_matches_primary_icon": True,
            "aliases": checked,
            "all_checks_passed": True,
            "device_tested": False,
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()
    if not __debug__:
        parser.exit(1, "Verification requires Python assertion checks; do not use -O.\n")
    try:
        report = verify(args.apk, Path(__file__).resolve().parents[1])
    except (
        AssertionError, KeyError, IndexError, ValueError, UnicodeError,
        struct.error, OSError, StopIteration, zipfile.BadZipFile,
    ) as error:
        parser.exit(1, f"Android launcher verification failed: {error}\n")
    output = json.dumps(report, indent=2) + "\n"
    if args.json_output:
        args.json_output.write_text(output, encoding="utf-8")
    print(output, end="")


if __name__ == "__main__":
    main()

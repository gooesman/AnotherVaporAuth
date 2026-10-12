"""Binary-format regression checks for the launcher release gate."""

import struct
import unittest

import verify_android_launcher as verifier


def utf8_pool(strings):
    offsets = []
    body = bytearray()

    def length(value):
        return bytes([value]) if value < 128 else bytes([128 | (value >> 8), value & 255])

    for text in strings:
        offsets.append(len(body))
        encoded = text.encode("utf-8")
        body.extend(length(len(text.encode("utf-16le")) // 2))
        body.extend(length(len(encoded)))
        body.extend(encoded + b"\0")
    body.extend(b"\0" * (-len(body) % 4))
    start = 28 + 4 * len(strings)
    return (
        struct.pack("<HHIIIIII", 1, 28, start + len(body), len(strings), 0, 256, start, 0)
        + b"".join(struct.pack("<I", offset) for offset in offsets)
        + body
    )


class AndroidBinaryResourceTests(unittest.TestCase):
    def test_compact_entries_use_key_and_type_from_the_entry_itself(self):
        keys = ["ava_launcher_label", "ic_launcher"]
        strings = ["gooesteamkit"]
        compact_string = struct.pack("<HHI", 0, (3 << 8) | 8, 0)
        self.assertEqual(
            verifier.table_entry(compact_string, 0, keys, strings),
            ("ava_launcher_label", "gooesteamkit"),
        )
        compact_reference = struct.pack("<HHI", 1, (1 << 8) | 8, 0x7F08002A)
        self.assertEqual(
            verifier.table_entry(compact_reference, 0, keys, strings),
            ("ic_launcher", {"ref": 0x7F08002A}),
        )

    def test_full_entry_reads_value_after_declared_header(self):
        full_string = struct.pack("<HHIHBBI", 8, 0, 0, 8, 0, 3, 0)
        self.assertEqual(
            verifier.table_entry(full_string, 0, ["label"], ["gooesteamkit"]),
            ("label", "gooesteamkit"),
        )
        with self.assertRaises(AssertionError):
            verifier.table_entry(struct.pack("<HHI", 0, 9, 0), 0, [], [])

    def test_utf8_pool_uses_byte_and_utf16_lengths_independently(self):
        strings = ["gooesteamkit", "鹅🪿" * 70, ""]
        self.assertEqual(verifier.pool(utf8_pool(strings), 0), strings)

    def test_utf16_pool_decodes_non_ascii_resource_names(self):
        text = "鹅图标"
        raw = struct.pack("<H", len(text)) + text.encode("utf-16le") + b"\0\0"
        raw += b"\0" * (-len(raw) % 4)
        data = struct.pack("<HHIIIIIII", 1, 28, 32 + len(raw), 1, 0, 0, 32, 0, 0) + raw
        self.assertEqual(verifier.pool(data, 0), [text])

    def test_chunk_size_cannot_overrun_the_file_or_stall(self):
        for invalid_size in (0, 7, 9):
            with self.subTest(invalid_size=invalid_size):
                data = struct.pack("<HHI", 1, 8, invalid_size)
                with self.assertRaises(AssertionError):
                    list(verifier.chunks(data, 0, len(data)))

    def test_binary_manifest_attributes_preserve_resource_refs_and_booleans(self):
        strings = ["activity-alias", "label", "enabled"]
        string_chunk = utf8_pool(strings)
        attributes = (
            struct.pack("<IIIHBBI", 0xFFFFFFFF, 1, 0xFFFFFFFF, 8, 0, 1, 0x7F12002A)
            + struct.pack("<IIIHBBI", 0xFFFFFFFF, 2, 0xFFFFFFFF, 8, 0, 18, 0)
        )
        start = (
            struct.pack("<HHIII", 0x102, 16, 36 + len(attributes), 1, 0xFFFFFFFF)
            + struct.pack("<IIHHHHHH", 0xFFFFFFFF, 0, 20, 20, 2, 0, 0, 0)
            + attributes
        )
        end = struct.pack("<HHIIIII", 0x103, 16, 24, 1, 0xFFFFFFFF, 0xFFFFFFFF, 0)
        contents = string_chunk + start + end
        xml = struct.pack("<HHI", 3, 8, 8 + len(contents)) + contents
        self.assertEqual(
            verifier.axml(xml),
            [{"name": "activity-alias", "depth": 0,
              "attrs": {"label": {"ref": 0x7F12002A}, "enabled": False}}],
        )


if __name__ == "__main__":
    unittest.main()

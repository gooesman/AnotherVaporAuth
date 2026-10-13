cmake_minimum_required(VERSION 3.15)
project(steam_client_native_test LANGUAGES CXX)
if(NOT WIN32)
  message(FATAL_ERROR "This regression suite exercises real Windows APIs.")
endif()
set(FLUTTER_WRAPPER_INCLUDE_DIR "" CACHE PATH "Flutter cpp_client_wrapper/include directory")
if(NOT EXISTS "${FLUTTER_WRAPPER_INCLUDE_DIR}/flutter/method_result.h")
  message(FATAL_ERROR "Set FLUTTER_WRAPPER_INCLUDE_DIR to Flutter's generated cpp_client_wrapper/include directory.")
endif()
add_executable(steam_client_native_test steam_client_bridge_test.cpp)
add_executable(steam_client_launch_fixture WIN32 steam_client_launch_fixture.cpp)
foreach(target steam_client_native_test steam_client_launch_fixture)
  target_compile_features(${target} PRIVATE cxx_std_17)
  target_compile_definitions(${target} PRIVATE UNICODE _UNICODE NOMINMAX)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /WX /EHsc /utf-8 /wd4100 /wd4505)
    # Standalone test executables must run on a clean Windows machine without
    # a Flutter engine DLL or an installed Visual C++ runtime.
    set_property(TARGET ${target} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  endif()
endforeach()
target_include_directories(steam_client_native_test PRIVATE "${FLUTTER_WRAPPER_INCLUDE_DIR}")
target_link_libraries(steam_client_native_test PRIVATE advapi32 dwmapi gdi32 user32)
target_link_libraries(steam_client_launch_fixture PRIVATE shell32)
add_dependencies(steam_client_native_test steam_client_launch_fixture)
enable_testing()
add_test(NAME steam_client_native_test COMMAND steam_client_native_test)

# Capture/codec regression links the actual Flutter standard codec (the Steam
# launch test above deliberately has no dependency on the Flutter runtime).
set(FLUTTER_ENGINE_DIR "" CACHE PATH "Flutter Windows engine/ephemeral directory")
if(NOT EXISTS "${FLUTTER_ENGINE_DIR}/flutter_windows.dll.lib")
  message(FATAL_ERROR "Set FLUTTER_ENGINE_DIR to the Windows engine directory; both native regression suites are required.")
endif()
add_executable(screen_qr_capture_test
  screen_qr_capture_test.cpp
  "${FLUTTER_ENGINE_DIR}/cpp_client_wrapper/core_implementations.cc"
  "${FLUTTER_ENGINE_DIR}/cpp_client_wrapper/standard_codec.cc")
target_compile_features(screen_qr_capture_test PRIVATE cxx_std_17)
target_compile_definitions(screen_qr_capture_test PRIVATE UNICODE _UNICODE NOMINMAX)
if(MSVC)
  target_compile_options(screen_qr_capture_test PRIVATE /W4 /WX /EHsc /utf-8 /wd4100 /wd4505)
  set_property(TARGET screen_qr_capture_test PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
target_include_directories(screen_qr_capture_test PRIVATE
  "${FLUTTER_ENGINE_DIR}" "${FLUTTER_WRAPPER_INCLUDE_DIR}")
target_link_libraries(screen_qr_capture_test PRIVATE
  "${FLUTTER_ENGINE_DIR}/flutter_windows.dll.lib" user32 gdi32 dwmapi)
add_custom_command(TARGET screen_qr_capture_test POST_BUILD COMMAND ${CMAKE_COMMAND}
  -E copy_if_different "${FLUTTER_ENGINE_DIR}/flutter_windows.dll"
  "$<TARGET_FILE_DIR:screen_qr_capture_test>")
add_test(NAME screen_qr_capture_test COMMAND screen_qr_capture_test)

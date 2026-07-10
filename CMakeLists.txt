cmake_minimum_required(VERSION 3.21)

project(BabelChrome VERSION 0.2.13 LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CONFIGURATION_TYPES Debug Release)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

set(PROJECT_ARCH "x86_64" CACHE STRING "Target macOS architecture.")
set(CMAKE_OSX_ARCHITECTURES "${PROJECT_ARCH}")

set(DEFAULT_CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/var/cef/cef_binary_149.0.2+ged5b3fd+chromium-149.0.7827.53_macosx64")
set(CEF_ROOT "${DEFAULT_CEF_ROOT}" CACHE PATH "Path to the CEF binary distribution.")
set(BABEL_CHROME_MODULES_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../modules" CACHE PATH "Path to BabelChrome PHP module source packages.")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CEF_ROOT}/cmake")

find_package(CEF REQUIRED)

add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)
add_subdirectory(src)

PRINT_CEF_CONFIG()

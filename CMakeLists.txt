cmake_minimum_required(VERSION 3.20)

project(Phantom LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

enable_testing()

# Public components are pinned by this superproject as Git submodules.  The
# shared core targets are idempotent, so this ordered list can build CGLib's
# base libraries and its higher-level modules alongside the dependent projects.
set(PHANTOM_PUBLIC_MODULES
    CGLib
    CGLib/Numerics
    CGLib/File
    CGLib/Scene
    CGLib/Volume
    Physics
    RayTracer
    CGLib/Renderer
    CGLib/GltfRenderer
    CGLib/Animation
    PointCloud
    CGLib/Space
    CGLib/Gizmo
    CGLib/Input
    CGLib/Particles
    CGLib/PostProcess)

foreach(module IN LISTS PHANTOM_PUBLIC_MODULES)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${module}/CMakeLists.txt")
        message(FATAL_ERROR
            "Required submodule '${module}' is unavailable. Clone with "
            "--recurse-submodules, or run: git submodule update --init --recursive")
    endif()

    add_subdirectory(${module})
endforeach()

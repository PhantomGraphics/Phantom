cmake_minimum_required(VERSION 3.20)

project(Phantom LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

enable_testing()

# Public components pinned by this superproject as Git submodules.
#
# CGLib became a self-contained CMake build (its top-level CMakeLists.txt now
# add_subdirectory()s every one of its own modules -- Numerics/File/Scene/
# Volume/Terrain/Space/Renderer/GltfRenderer/Animation/Gizmo/Input/Particles/
# PostProcess -- and registers their tests). So this list only names CGLib once
# plus the projects that sit on top of it; listing CGLib's sub-modules here as
# well would add the same source directories a second time ("binary directory
# is already used to build a source directory").
#
# CGLib defaults its test suites off when it is add_subdirectory()'d rather than
# top-level; the superproject wants them, so force the option on before pulling
# CGLib in. The shared phantom_add_*_core() builders are idempotent, so the
# Physics/RayTracer/PointCloud entries reuse whatever CGLib already built.
set(CGLIB_BUILD_TESTING ON CACHE BOOL "Build CGLib's GoogleTest suites" FORCE)

# Repo-root-relative includes ("CGLib/Math/Vector3d.h", "Physics/Physics/
# RigidBody.h") are the convention across every module here. Each module's own
# CMakeLists.txt puts its REPO_ROOT (= this directory) on the include path of
# the targets it owns, but the shared Vulkan-app core libs (VkAppBaseCore,
# VkRendererCore, ...) are built by whichever module is configured first --
# CGLib, whose standalone build resolves "CGLib/..." through a generated
# forwarding-header tree rather than this real parent directory. Anchoring the
# include path here, before any add_subdirectory(), makes both prefixes resolve
# for every target regardless of who builds the shared core first.
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# CGLib's *Core.lib static libraries are consumed by the private CGApp msbuild layer
# (CGApp/build_cgapp.ps1 -> Phantom2026.sln). Those .vcxproj files resolve every CGLib core
# lib from build/<preset>/CGLib/. CGLib's own build instead drops each in the subdirectory of
# whichever module first defines the shared target -- an internal ordering detail that shifts
# as modules are added (e.g. VkAppBaseCore moved from CGLib/Volume/ to CGLib/Animation/ once
# the superproject started building every CGLib module). Pin them all to build/<preset>/CGLib/
# so the CGApp .vcxproj library paths stay correct. Scoped to CGLib only -- Physics/RayTracer/
# PointCloud keep their own per-module output dirs (CGApp .vcxproj files reference those too).
set(_phantom_saved_archive_dir "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/CGLib")
add_subdirectory(CGLib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${_phantom_saved_archive_dir}")

set(PHANTOM_PUBLIC_MODULES
    Physics
    RayTracer
    PointCloud)

foreach(module IN LISTS PHANTOM_PUBLIC_MODULES)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${module}/CMakeLists.txt")
        message(FATAL_ERROR
            "Required submodule '${module}' is unavailable. Clone with "
            "--recurse-submodules, or run: git submodule update --init --recursive")
    endif()

    add_subdirectory(${module})
endforeach()

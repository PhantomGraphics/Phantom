# Idempotent GoogleTest discovery, shared by every *Test target across this
# repo's standalone-per-module and root CMake builds
# (docs/todo/PLAN_crossplatform_non_cgapp_build.md Phase 4 §5.4 item 1 --
# extracted from the near-identical find_package(GTest)+NuGet-fallback block
# that used to be copy-pasted into every one of CGLib/, Crystal/Space,
# Crystal/Volume, Crystal/File, Crystal/Numerics, Crystal/Scene,
# Crystal/Animation, Crystal/GltfRenderer, Physics, PointCloud, RayTracer's
# own CMakeLists.txt).
#
# Call crystal_find_gtest() once per CMakeLists.txt that defines a *Test
# target, then check CRYSTAL_GTEST_FOUND. Safe to call from more than one
# add_subdirectory()'d module in the same configure -- the underlying
# GTest::gtest/GTest::gtest_main imported targets are only ever created once
# (guarded by the CRYSTAL_GTEST_FOUND cache entry itself), every later caller
# just reuses them.
#
# Requires REPO_ROOT to already be set by the caller (absolute path to the
# repo root, used to locate the vendored NuGet GTest package under packages/
# on Windows when no system GTest is found).
#
# Linux: needs libgtest-dev (find_package(GTest), a system package -- no
# fallback is attempted, matching every pre-Phase-4 copy of this block).
# Windows: reuses the same prebuilt NuGet package every .vcxproj Test project
# already restores (Microsoft.googletest.v140.windesktop.msvcstl.static.
# rt-dyn.1.8.1.7), not a second GTest source/version.

function(crystal_find_gtest)
    # Deliberately NOT gated on the CRYSTAL_GTEST_FOUND *value* below: that's a CACHE INTERNAL
    # entry, so it persists in CMakeCache.txt across separate `cmake` invocations on the same
    # build dir, but the GTest::gtest/GTest::gtest_main IMPORTED targets it's meant to guard do
    # NOT persist (IMPORTED targets are recreated fresh every configure pass, cache or not) --
    # gating on the cache entry meant a second `cmake --preset ...` re-configure of an
    # already-configured build dir returned early here without ever recreating those targets,
    # so every later `target_link_libraries(FooTest ... GTest::gtest ...)` failed with "target
    # was not found" (found running CGApp/build_cgapp.ps1 twice in a row, Phase 5 of
    # docs/todo/PLAN_crossplatform_non_cgapp_build.md). Gate on target existence instead, same
    # idiom every crystal_add_*_core() guard in CrystalCoreLibs.cmake/CrystalVulkanApp.cmake
    # already uses -- true only once actually (re)created within the current configure pass.
    if(TARGET GTest::gtest OR TARGET GTest::gtest_main)
        return()
    endif()

    find_package(GTest)

    # find_package(GTest) creates GTest::gtest/GTest::gtest_main as IMPORTED
    # targets scoped to this directory (CGLib's, since crystal_find_gtest()'s
    # actual search only ever runs once, guarded by the CACHE check above) --
    # unlike regular add_library() targets (MathCore etc.), IMPORTED targets
    # are NOT visible from sibling add_subdirectory() trees by default.
    # Promote them to global so every *Test target across every module (only
    # some of which are inside CGLib's own directory tree) can link them.
    if(GTest_FOUND AND TARGET GTest::gtest)
        set_target_properties(GTest::gtest PROPERTIES IMPORTED_GLOBAL TRUE)
    endif()
    if(GTest_FOUND AND TARGET GTest::gtest_main)
        set_target_properties(GTest::gtest_main PROPERTIES IMPORTED_GLOBAL TRUE)
    endif()

    if(NOT GTest_FOUND AND WIN32)
        set(_nuget_root ${REPO_ROOT}/packages/Microsoft.googletest.v140.windesktop.msvcstl.static.rt-dyn.1.8.1.7)

        if(EXISTS ${_nuget_root})
            set(_config "Release")
            if(CMAKE_BUILD_TYPE STREQUAL "Debug")
                set(_config "Debug")
            endif()
            set(_libdir ${_nuget_root}/lib/native/v140/windesktop/msvcstl/static/rt-dyn/x64/${_config})

            if(_config STREQUAL "Debug")
                set(_lib_name gtestd.lib)
                set(_main_lib_name gtest_maind.lib)
            else()
                set(_lib_name gtest.lib)
                set(_main_lib_name gtest_main.lib)
            endif()

            add_library(GTest::gtest STATIC IMPORTED GLOBAL)
            set_target_properties(GTest::gtest PROPERTIES
                IMPORTED_LOCATION ${_libdir}/${_lib_name}
                INTERFACE_INCLUDE_DIRECTORIES ${_nuget_root}/build/native/include
            )
            add_library(GTest::gtest_main STATIC IMPORTED GLOBAL)
            set_target_properties(GTest::gtest_main PROPERTIES
                IMPORTED_LOCATION ${_libdir}/${_main_lib_name}
                INTERFACE_LINK_LIBRARIES GTest::gtest
            )
            set(GTest_FOUND TRUE)
            message(STATUS "Crystal: using vendored NuGet GTest from ${_nuget_root} (${_config})")
        else()
            message(WARNING "Crystal: NuGet GTest package not found at ${_nuget_root} -- *Test targets are skipped. Restore it once via any .vcxproj-based build first.")
        endif()
    endif()

    set(CRYSTAL_GTEST_FOUND ${GTest_FOUND} CACHE INTERNAL "Whether GTest::gtest/GTest::gtest_main are available")
endfunction()

# CGLib owns the Vulkan/GLFW discovery and the GPU/UI core-library builders (VulkanGraphics,
# UIWidgets, VkAppBase, VkRenderer, GltfRenderer, VolumeRenderer, ...). Standalone
# Physics/PointCloud/RayTracer builds reach them through this forwarder, so there is a single
# definition (a second full copy used to live here and drifted from CGLib's).
#
# Only phantom_add_runtime_shaders()/phantom_find_glslc() below are specific to this repo's
# viewers (Physics/PointCloud/RayTracer compile their GLSL at build time; CGLib ships its .spv).
include("${CMAKE_CURRENT_LIST_DIR}/../CGLib/cmake/PhantomVulkanApp.cmake")

# ---------------------------------------------------------------------------
# phantom_add_runtime_shaders(<target> <shader_dir> [<shader_dir> ...])
#
# Compiles every *.vert/*.frag/*.comp under the given source directories to
# SPIR-V with glslc and copies the results next to <target>'s executable as
# "shaders/<name>.spv" (a POST_BUILD copy_directory, matching each app's
# historical MSBuild PostBuildEvent). The *.spv files are intentionally
# Git-ignored, so on a clean checkout merely copying the GLSL source dir is
# not enough -- VulkanSPVResolver.h would hand vkCreateShaderModule a
# zero-sized blob and the viewer crashes at startup. Promoted here from
# Physics/CMakeLists.txt so PointCloud/PointCloudView (and GSView) get the
# same treatment.
#
# When two source directories contain a shader with the same file name, the
# one listed FIRST wins (the later dir's copy is skipped). PointCloudView
# relies on this: it passes PointRenderer/shaders before PointCloudView/shaders
# so PointRenderer's point.vert/gs_splat.frag (which its VkPointRenderer
# pipeline expects) are used, while PointCloudView/shaders still supplies the
# triangle.* pair PointRenderer does not have -- matching the old build's
# "copy PointCloudView/shaders, then let PointRenderer/shaders overwrite" order.
# ---------------------------------------------------------------------------

function(phantom_find_glslc)
    if(DEFINED PHANTOM_GLSLC_EXECUTABLE AND PHANTOM_GLSLC_EXECUTABLE)
        return()
    endif()
    find_program(PHANTOM_GLSLC_EXECUTABLE
        NAMES glslc glslc.exe
        HINTS "$ENV{VULKAN_SDK}/Bin" "$ENV{VULKAN_SDK}/bin")
    if(NOT PHANTOM_GLSLC_EXECUTABLE)
        message(FATAL_ERROR
            "Vulkan viewers require glslc to compile runtime shaders. "
            "Install the Vulkan SDK or set VULKAN_SDK.")
    endif()
endfunction()

function(phantom_add_runtime_shaders target)
    phantom_find_glslc()
    set(shader_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${target}_shaders")
    set(shader_outputs)
    set(shader_seen_names)
    foreach(shader_dir IN LISTS ARGN)
        file(GLOB shader_sources CONFIGURE_DEPENDS
            "${shader_dir}/*.vert" "${shader_dir}/*.frag" "${shader_dir}/*.comp")
        foreach(shader_source IN LISTS shader_sources)
            get_filename_component(shader_name "${shader_source}" NAME)
            if(shader_name IN_LIST shader_seen_names)
                continue()  # earlier-listed dir already provided this file name
            endif()
            list(APPEND shader_seen_names "${shader_name}")
            set(shader_output "${shader_output_dir}/${shader_name}.spv")
            # Shaders may #include shared GLSL headers (GSView's gps_*.comp,
            # PhysicsView's flame_*). DEPENDS alone only knows the top-level
            # file, so a header-only edit left a stale .spv; with Ninja, let
            # glslc emit a Makefile-style depfile so the header is a real edge.
            if(CMAKE_GENERATOR MATCHES "Ninja")
                set(shader_depfile "${shader_output}.d")
                add_custom_command(
                    OUTPUT "${shader_output}"
                    COMMAND ${CMAKE_COMMAND} -E make_directory "${shader_output_dir}"
                    COMMAND "${PHANTOM_GLSLC_EXECUTABLE}" -MD -MF "${shader_depfile}"
                            "${shader_source}" -o "${shader_output}"
                    DEPENDS "${shader_source}"
                    DEPFILE "${shader_depfile}"
                    COMMENT "Compiling ${shader_name}"
                    VERBATIM)
            else()
                add_custom_command(
                    OUTPUT "${shader_output}"
                    COMMAND ${CMAKE_COMMAND} -E make_directory "${shader_output_dir}"
                    COMMAND "${PHANTOM_GLSLC_EXECUTABLE}" "${shader_source}" -o "${shader_output}"
                    DEPENDS "${shader_source}"
                    COMMENT "Compiling ${shader_name}"
                    VERBATIM)
            endif()
            list(APPEND shader_outputs "${shader_output}")
        endforeach()
    endforeach()

    add_custom_target(${target}Shaders DEPENDS ${shader_outputs})
    add_dependencies(${target} ${target}Shaders)

    # A TARGET POST_BUILD command only re-runs when the target itself relinks
    # (Ninja generator): a GLSL-only edit recompiles shader_outputs above but
    # does not touch any .obj/.lib the linker reads, so the exe is considered
    # up to date and the copy below was silently skipped, leaving a stale
    # runtime/shaders/*.spv next to the exe (discovered via
    # PLAN_pbvr_gps_ensemble_lod.md Phase 4 bank-reuse debugging: the ${target}
    # rebuild logged "Compiling X.comp" yet the exe kept running the pre-edit
    # shader). Route it through its own OUTPUT/DEPENDS custom command instead,
    # so it is a real Ninja edge keyed on shader_outputs, independent of
    # whether the exe relinks.
    set(shader_copy_stamp "${shader_output_dir}/.copied_to_runtime")
    add_custom_command(
        OUTPUT "${shader_copy_stamp}"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${shader_output_dir}" "$<TARGET_FILE_DIR:${target}>/shaders"
        COMMAND ${CMAKE_COMMAND} -E touch "${shader_copy_stamp}"
        DEPENDS ${shader_outputs}
        COMMENT "Copying ${target} runtime shaders"
        VERBATIM)
    add_custom_target(${target}ShadersCopy DEPENDS "${shader_copy_stamp}")
    add_dependencies(${target} ${target}ShadersCopy)
endfunction()

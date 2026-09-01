# Idempotent, GUI/Vulkan-independent core-library builders shared across this
# repo's standalone-per-module and root CMake builds
# (docs/todo/PLAN_crossplatform_non_cgapp_build.md Phase 4 §5.4 item 1 --
# extracted from the near-identical MathCore/GraphicsCore/NumericsCore/
# SceneCore/SpaceCore/VolumeCore/FileCore/AnimationCore blocks that used to be
# copy-pasted, with per-file variable-name variations, into every one of
# Crystal/Space, Crystal/Volume, Crystal/File, Crystal/Numerics, Crystal/Scene,
# Crystal/Animation, Crystal/GltfRenderer, Crystal/Renderer, Physics,
# PointCloud, RayTracer's own CMakeLists.txt).
#
# Each crystal_add_*_core() function is a no-op if its target already exists
# (`if(TARGET ...) return()` guard), so calling the same function from
# multiple add_subdirectory()'d modules in one root configure is safe --
# whichever module is processed first actually creates the target; every
# later caller just reuses it via target_link_libraries. This also means a
# module that itself needs another module's core lib (e.g. VolumeCore needs
# SpaceCore) just calls that module's crystal_add_*_core() function directly
# instead of duplicating its source list inline, which is the actual
# duplication removal this file exists for (pre-Phase-4, every file bundled
# its dependencies' raw .cpp sources into its own target instead).
#
# Callers must set these variables in their own scope before calling any
# function here (every existing CMakeLists.txt in this repo already computes
# them the same way -- see e.g. CGLib/Space/CMakeLists.txt):
#   CGLIB_ROOT          -- absolute path to CGLib/
#   REPO_ROOT            -- absolute path to the repo root
#   CRYSTAL_WARN_FLAGS   -- /W3 (MSVC) or -Wall (else)
#
# Every target here is promoted to C++20 via target_compile_features (not by
# changing CMAKE_CXX_STANDARD globally) -- these libraries get linked into the
# Vulkan/VkAppBase app chain (see CrystalVulkanApp.cmake) in every module that
# uses them, which needs C++20 (VkAppBase.cpp's std::string_view::
# starts_with), and this repo's portable geometry/IO/animation code has
# already been verified to compile identically as C++20 everywhere a
# pre-Phase-4 file tried it (Space/PointCloud/File/GltfRenderer/RayTracer's
# standalone builds already compiled these same sources as C++20). This
# matches the per-target promotion pattern (target_compile_features rather
# than a global bump) documented in Physics/Volume/Animation's CMakeLists.txt
# before this file existed -- kept per-target here too, so a module whose own
# project() still defaults to C++17 (e.g. Crystal/Numerics, Crystal/Scene
# standalone) is unaffected everywhere except these specific shared targets.
#
# Include directories are declared PUBLIC (not PRIVATE, as the pre-Phase-4
# per-file copies did) so a consumer just needs target_link_libraries(... X)
# to get X's required include paths transitively -- this removes another
# large chunk of the pre-Phase-4 duplication, where every single executable
# re-listed e.g. VulkanGraphicsCore's/UIWidgetsCore's include dirs itself.

function(crystal_add_math_core)
    if(TARGET MathCore)
        return()
    endif()
    file(GLOB _math_sources ${CGLIB_ROOT}/Math/*.cpp)
    list(FILTER _math_sources EXCLUDE REGEX "pch\\.cpp$")
    add_library(MathCore STATIC ${_math_sources})
    target_include_directories(MathCore PUBLIC ${CGLIB_ROOT})
    target_compile_options(MathCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(MathCore PRIVATE cxx_std_20)
endfunction()

function(crystal_add_graphics_core)
    if(TARGET GraphicsCore)
        return()
    endif()
    crystal_add_math_core()
    file(GLOB _graphics_sources ${CGLIB_ROOT}/Graphics/*.cpp)
    list(FILTER _graphics_sources EXCLUDE REGEX "pch\\.cpp$")
    add_library(GraphicsCore STATIC ${_graphics_sources})
    target_include_directories(GraphicsCore PUBLIC ${CGLIB_ROOT})
    target_link_libraries(GraphicsCore PUBLIC MathCore)
    target_compile_options(GraphicsCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(GraphicsCore PRIVATE cxx_std_20)
endfunction()

function(crystal_add_numerics_core)
    if(TARGET NumericsCore)
        return()
    endif()
    add_library(NumericsCore STATIC
        ${CGLIB_ROOT}/Numerics/Numerics/Converter.cpp
        ${CGLIB_ROOT}/Numerics/Numerics/SVD2d.cpp
        ${CGLIB_ROOT}/Numerics/Numerics/SVD3d.cpp
    )
    target_include_directories(NumericsCore PUBLIC ${REPO_ROOT})
    target_compile_options(NumericsCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(NumericsCore PRIVATE cxx_std_20)
endfunction()

function(crystal_add_space_core)
    if(TARGET SpaceCore)
        return()
    endif()
    crystal_add_math_core()
    file(GLOB _space_sources ${CGLIB_ROOT}/Space/Space/*.cpp)
    list(FILTER _space_sources EXCLUDE REGEX "pch\\.cpp$")
    add_library(SpaceCore STATIC ${_space_sources})
    target_include_directories(SpaceCore PUBLIC ${REPO_ROOT})
    target_link_libraries(SpaceCore PUBLIC MathCore)
    target_compile_options(SpaceCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(SpaceCore PRIVATE cxx_std_20)

    # IndexedSortBasedSearcher.cpp's #pragma omp parallel for is silently a
    # no-op without this -- unlike Physics/PointCloud's own CMakeLists.txt
    # (which each find_package(OpenMP) themselves), SpaceCore previously had
    # no OpenMP link of its own, so the CMake build's neighbor search ran
    # fully serial even though the same source compiles multithreaded in the
    # MSBuild/Blender-addon build (docs/issue/wcsph_parallel_scaling_profile.md
    # section 7).
    find_package(OpenMP)
    if(OpenMP_CXX_FOUND)
        target_link_libraries(SpaceCore PUBLIC OpenMP::OpenMP_CXX)
    endif()
endfunction()

function(crystal_add_scene_core)
    if(TARGET SceneCore)
        return()
    endif()
    crystal_add_math_core()
    # NOTE on Scene's on-disk source list: Scene/Scene/ also contains
    # ParticleSystemIdPresenter.cpp/.h, ParticleSystemPresenter.cpp/.h,
    # TriangleMeshPresenter.cpp/.h and WireFramePresenter.cpp/.h -- these are
    # deliberately NOT part of Scene.vcxproj's <ClCompile> list (Scene.vcxproj.
    # filters is stale and still lists them) because they pull in Crystal/
    # Renderer/Renderer/PointRenderer.h, a GUI/Vulkan-facing header outside
    # this Vulkan-free module's real dependency set. Do NOT file(GLOB) this
    # directory -- the explicit list below matches Scene.vcxproj exactly.
    add_library(SceneCore STATIC
        ${CGLIB_ROOT}/Scene/Scene/ParticleSystem.cpp
        ${CGLIB_ROOT}/Scene/Scene/ParticleSystemBuilder.cpp
        ${CGLIB_ROOT}/Scene/Scene/ParticleSystemScene.cpp
        ${CGLIB_ROOT}/Scene/Scene/SceneBase.cpp
        ${CGLIB_ROOT}/Scene/Scene/SceneGroup.cpp
        ${CGLIB_ROOT}/Scene/Scene/TriangleMesh.cpp
        ${CGLIB_ROOT}/Scene/Scene/TriangleMeshBuilder.cpp
        ${CGLIB_ROOT}/Scene/Scene/WireFrame.cpp
        ${CGLIB_ROOT}/Scene/Scene/WireFrameBuilder.cpp
        ${CGLIB_ROOT}/Scene/Scene/WireFrameScene.cpp
    )
    target_include_directories(SceneCore PUBLIC ${REPO_ROOT})
    target_link_libraries(SceneCore PUBLIC MathCore)
    target_compile_options(SceneCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(SceneCore PRIVATE cxx_std_20)
endfunction()

function(crystal_add_volume_core)
    if(TARGET VolumeCore)
        return()
    endif()
    crystal_add_math_core()
    crystal_add_space_core()
    # NOTE on OpenVDB: SparseVolumeTree/{VdbReader,VdbWriter}.h read/write the
    # raw .vdb file format using only the C++ standard library -- no OpenVDB
    # library dependency despite the file names (see those headers' own
    # comments). No find_package/system package needed for it.
    add_library(VolumeCore STATIC
        ${CGLIB_ROOT}/Volume/Volume/LevelSet.cpp
        ${CGLIB_ROOT}/Volume/Volume/MCSurfaceBuilder.cpp
        ${CGLIB_ROOT}/Volume/Volume/SurfaceVoxelizer.cpp
        ${CGLIB_ROOT}/Volume/Volume/Volume.cpp
        ${CGLIB_ROOT}/Volume/Volume/VolumeNode.cpp
    )
    target_include_directories(VolumeCore PUBLIC ${REPO_ROOT})
    target_link_libraries(VolumeCore PUBLIC MathCore SpaceCore)
    target_compile_options(VolumeCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(VolumeCore PRIVATE cxx_std_20)
endfunction()

function(crystal_add_file_core)
    if(TARGET FileCore)
        return()
    endif()
    crystal_add_math_core()
    crystal_add_graphics_core()
    # NOTE on File's on-disk source list: File/File/ also contains File.cpp, a
    # never-wired-up leftover from the original VS "static library" project
    # template (a stub fnFile() nobody calls) -- confirmed NOT part of File.
    # vcxproj's <ClCompile> list. Do NOT file(GLOB) this directory -- the
    # explicit list below matches File.vcxproj exactly. cgltf (GLTFFileReader/
    # Writer) is a single-header library under File/ThirdParty/cgltf, included
    # via the repo-root-relative path "CGLib/File/ThirdParty/cgltf/cgltf.h"
    # -- no extra include dir needed beyond REPO_ROOT (already PUBLIC below).
    add_library(FileCore STATIC
        ${CGLIB_ROOT}/File/File/BVHFileReader.cpp
        ${CGLIB_ROOT}/File/File/GLTFFileReader.cpp
        ${CGLIB_ROOT}/File/File/GLTFFileWriter.cpp
        ${CGLIB_ROOT}/File/File/MTLFileReader.cpp
        ${CGLIB_ROOT}/File/File/MTLFileWriter.cpp
        ${CGLIB_ROOT}/File/File/OBJFileReader.cpp
        ${CGLIB_ROOT}/File/File/OBJFileWriter.cpp
        ${CGLIB_ROOT}/File/File/OBJSyntaxParser.cpp
        ${CGLIB_ROOT}/File/File/PLYFileReader.cpp
        ${CGLIB_ROOT}/File/File/PLYFileWriter.cpp
        ${CGLIB_ROOT}/File/File/PMDFileReader.cpp
        ${CGLIB_ROOT}/File/File/PMXFileReader.cpp
        ${CGLIB_ROOT}/File/File/STLFileReader.cpp
        ${CGLIB_ROOT}/File/File/STLFileWriter.cpp
        ${CGLIB_ROOT}/File/File/VMDFileReader.cpp
    )
    target_include_directories(FileCore PUBLIC ${REPO_ROOT})
    target_link_libraries(FileCore PUBLIC MathCore GraphicsCore)
    target_compile_options(FileCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(FileCore PRIVATE cxx_std_20)
endfunction()

function(crystal_add_animation_core)
    if(TARGET AnimationCore)
        return()
    endif()
    crystal_add_math_core()
    # NOTE on VMDConverter.cpp: VMD's Shift-JIS(CP932)->UTF-8 text decoding is
    # #ifdef _WIN32-split -- Windows keeps <windows.h>'s MultiByteToWideChar/
    # WideCharToMultiByte(932, ...), Linux uses glibc's
    # iconv("UTF-8", "CP932") (always available, no extra link dependency).
    add_library(AnimationCore STATIC
        ${CGLIB_ROOT}/Animation/Animation/Animator.cpp
        ${CGLIB_ROOT}/Animation/Animation/BVHConverter.cpp
        ${CGLIB_ROOT}/Animation/Animation/IKSolver.cpp
        ${CGLIB_ROOT}/Animation/Animation/MorphAnimator.cpp
        ${CGLIB_ROOT}/Animation/Animation/PMXConverter.cpp
        ${CGLIB_ROOT}/Animation/Animation/Skeleton.cpp
        ${CGLIB_ROOT}/Animation/Animation/VMDConverter.cpp
    )
    target_include_directories(AnimationCore PUBLIC ${REPO_ROOT} ${CGLIB_ROOT}/ThirdParty/glm-0.9.9.8)
    target_link_libraries(AnimationCore PUBLIC MathCore)
    target_compile_options(AnimationCore PRIVATE ${CRYSTAL_WARN_FLAGS})
    target_compile_features(AnimationCore PRIVATE cxx_std_20)
endfunction()

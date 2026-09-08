# Phantom

Phantom is the public integration repository for a C++ graphics and physics
research framework. It pins the public components at compatible revisions and
builds them together with CMake.

`CGApp` is intentionally not part of this repository. It remains in a
separate private integration repository.

## Layout

```text
Phantom/
├── cmake/         # shared CMake modules used by the public components
├── CGLib/        # Git submodule: common graphics and numerical libraries
├── Physics/      # Git submodule: physics simulation
├── PointCloud/   # Git submodule: point-cloud processing and rendering
└── RayTracer/    # Git submodule: ray tracing
```

## Clone and build

After the component repositories have been registered as submodules, clone
with their pinned revisions:

```powershell
git clone --recurse-submodules git@github-phantom:PhantomGraphics/Phantom.git
cmake --preset windows-debug
cmake --build --preset windows-debug
ctest --preset windows-debug
```

For an existing checkout:

```powershell
git submodule update --init --recursive
```

### Visual Studio solution

The Ninja presets above are the build of record. To develop in the Visual
Studio 2026 IDE, use the `windows-vs` preset instead — it runs the CMake
"Visual Studio 18 2026" generator and writes `Phantom.slnx` plus one
`.vcxproj` per target under `build/windows-vs/` (git-ignored, regenerated on
every configure, so it never drifts from the CMake build):

```powershell
cmake --preset windows-vs
start build\windows-vs\Phantom.slnx
```

It is a multi-config solution — choose Debug/Release in the VS toolbar.
(VS 2026 can also just "Open Folder" on this directory and use any preset
directly; the `windows-vs` preset is only needed when you specifically want
a `.slnx`/`.vcxproj` tree.)

## Component ownership

Each component is independently buildable and publishes its own source,
tests, documentation, and releases. This repository only owns integration:
the component revision pins, shared build presets, and cross-component CI.

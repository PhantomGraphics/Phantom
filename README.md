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

## Component ownership

Each component is independently buildable and publishes its own source,
tests, documentation, and releases. This repository only owns integration:
the component revision pins, shared build presets, and cross-component CI.

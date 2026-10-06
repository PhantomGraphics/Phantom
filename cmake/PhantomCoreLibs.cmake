# CGLib owns the CPU-only core-library builders (Math/Graphics/Numerics/Space/Scene/Volume/
# File/Animation/GeometryNode/Asset/SceneRuntime). Standalone Physics/PointCloud/RayTracer
# builds reach them through this forwarder, so there is a single definition (a second full copy
# used to live here and drifted from CGLib's).
include("${CMAKE_CURRENT_LIST_DIR}/../CGLib/cmake/PhantomCoreLibs.cmake")

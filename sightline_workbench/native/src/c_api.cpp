#include "sightline/c_api.h"

#include "sightline/core.hpp"
#include "sightline/version.hpp"

namespace {

[[nodiscard]] sightline::Vec3d from_c(sl_vec3d value) noexcept {
    return {value.x, value.y, value.z};
}

[[nodiscard]] sl_vec3d to_c(sightline::Vec3d value) noexcept {
    return {value.x, value.y, value.z};
}

[[nodiscard]] sl_intersection_status to_c(
    sightline::IntersectionStatus status) noexcept {
    return static_cast<sl_intersection_status>(status);
}

}  // namespace

extern "C" const char* sl_version(void) {
    return SIGHTLINE_NATIVE_VERSION_STRING;
}

extern "C" sl_intersection_status sl_intersect_forward_plane(
    const sl_plane* plane,
    sl_vec3d ray_origin,
    sl_vec3d ray_direction,
    double parallel_tolerance,
    sl_plane_intersection* output) {
    if (plane == nullptr || output == nullptr) {
        return SL_INTERSECTION_INVALID_INPUT;
    }
    const sightline::Plane native_plane{
        from_c(plane->origin),
        from_c(plane->normal),
        from_c(plane->basis_x),
        from_c(plane->basis_y)};
    const sightline::PlaneIntersection result =
        sightline::intersect_forward_plane(
            native_plane,
            from_c(ray_origin),
            from_c(ray_direction),
            parallel_tolerance);
    output->status = to_c(result.status);
    output->range = result.range;
    output->world = to_c(result.world);
    output->plane = {result.plane.x, result.plane.y};
    return output->status;
}

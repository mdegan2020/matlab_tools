#include "sightline/core.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace sightline {
namespace {

[[nodiscard]] bool finite(Vec3d value) noexcept {
    return std::isfinite(value.x) && std::isfinite(value.y) &&
           std::isfinite(value.z);
}

[[nodiscard]] Vec3d subtract(Vec3d lhs, Vec3d rhs) noexcept {
    return {lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z};
}

[[nodiscard]] Vec3d add(Vec3d lhs, Vec3d rhs) noexcept {
    return {lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z};
}

[[nodiscard]] Vec3d scale(Vec3d value, double factor) noexcept {
    return {factor * value.x, factor * value.y, factor * value.z};
}

[[nodiscard]] PlaneIntersection invalid_result(
    IntersectionStatus status) noexcept {
    const double nan = std::numeric_limits<double>::quiet_NaN();
    return {status, nan, {nan, nan, nan}, {nan, nan}};
}

}  // namespace

double dot(Vec3d lhs, Vec3d rhs) noexcept {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
}

Vec3d cross(Vec3d lhs, Vec3d rhs) noexcept {
    return {
        lhs.y * rhs.z - lhs.z * rhs.y,
        lhs.z * rhs.x - lhs.x * rhs.z,
        lhs.x * rhs.y - lhs.y * rhs.x};
}

double norm(Vec3d value) noexcept {
    return std::sqrt(dot(value, value));
}

bool is_valid_plane(const Plane& plane, double tolerance) noexcept {
    if (!finite(plane.origin) || !finite(plane.normal) ||
        !finite(plane.basis_x) || !finite(plane.basis_y) ||
        !std::isfinite(tolerance) || tolerance <= 0.0) {
        return false;
    }
    const double handedness = dot(cross(plane.basis_x, plane.basis_y),
                                  plane.normal);
    const double maximum_error = std::max({
        std::abs(norm(plane.normal) - 1.0),
        std::abs(norm(plane.basis_x) - 1.0),
        std::abs(norm(plane.basis_y) - 1.0),
        std::abs(dot(plane.normal, plane.basis_x)),
        std::abs(dot(plane.normal, plane.basis_y)),
        std::abs(dot(plane.basis_x, plane.basis_y)),
        std::abs(handedness - 1.0)});
    return maximum_error <= tolerance;
}

Vec3d reconstruct_plane(const Plane& plane, Vec2d coordinates) noexcept {
    return add(plane.origin,
               add(scale(plane.basis_x, coordinates.x),
                   scale(plane.basis_y, coordinates.y)));
}

PlaneIntersection intersect_forward_plane(
    const Plane& plane,
    Vec3d ray_origin,
    Vec3d ray_direction,
    double parallel_tolerance) noexcept {
    if (!is_valid_plane(plane) || !finite(ray_origin) ||
        !finite(ray_direction) || !std::isfinite(parallel_tolerance) ||
        parallel_tolerance <= 0.0 ||
        std::abs(norm(ray_direction) - 1.0) > 1.0e-10) {
        return invalid_result(IntersectionStatus::invalid_input);
    }

    const double denominator = dot(plane.normal, ray_direction);
    if (std::abs(denominator) <= parallel_tolerance) {
        return invalid_result(IntersectionStatus::parallel);
    }
    const double range = dot(plane.normal, subtract(plane.origin, ray_origin)) /
                         denominator;
    if (!std::isfinite(range)) {
        return invalid_result(IntersectionStatus::invalid_input);
    }
    if (range <= 0.0) {
        return invalid_result(IntersectionStatus::behind_origin);
    }

    const Vec3d world = add(ray_origin, scale(ray_direction, range));
    const Vec3d relative = subtract(world, plane.origin);
    return {
        IntersectionStatus::ok,
        range,
        world,
        {dot(plane.basis_x, relative), dot(plane.basis_y, relative)}};
}

}  // namespace sightline

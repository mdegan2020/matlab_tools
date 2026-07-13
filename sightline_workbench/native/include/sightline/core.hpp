#pragma once

#include <cstdint>

namespace sightline {

struct Vec2d final {
    double x{};
    double y{};
};

struct Vec3d final {
    double x{};
    double y{};
    double z{};
};

struct Plane final {
    Vec3d origin{};
    Vec3d normal{};
    Vec3d basis_x{};
    Vec3d basis_y{};
};

enum class IntersectionStatus : std::int32_t {
    ok = 0,
    parallel = 1,
    behind_origin = 2,
    invalid_input = 3
};

struct PlaneIntersection final {
    IntersectionStatus status{IntersectionStatus::invalid_input};
    double range{};
    Vec3d world{};
    Vec2d plane{};

    [[nodiscard]] bool valid() const noexcept {
        return status == IntersectionStatus::ok;
    }
};

[[nodiscard]] double dot(Vec3d lhs, Vec3d rhs) noexcept;
[[nodiscard]] Vec3d cross(Vec3d lhs, Vec3d rhs) noexcept;
[[nodiscard]] double norm(Vec3d value) noexcept;
[[nodiscard]] bool is_valid_plane(
    const Plane& plane, double tolerance = 1.0e-10) noexcept;
[[nodiscard]] Vec3d reconstruct_plane(
    const Plane& plane, Vec2d coordinates) noexcept;
[[nodiscard]] PlaneIntersection intersect_forward_plane(
    const Plane& plane,
    Vec3d ray_origin,
    Vec3d ray_direction,
    double parallel_tolerance = 1.0e-12) noexcept;

}  // namespace sightline

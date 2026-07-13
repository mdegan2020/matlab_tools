#include "sightline/core.hpp"

#include <Eigen/Core>

#include <chrono>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>

int main() {
    constexpr std::size_t iterations = 1'000'000U;
    const Eigen::Vector3d plane_origin(1000.0, -2000.0, 300.0);
    const Eigen::Vector3d normal(
        0.5196152422706632, -0.6928203230275509, 0.5);
    const Eigen::Matrix<double, 3, 2> basis =
        (Eigen::Matrix<double, 3, 2>() <<
             0.8, -0.3,
             0.6, 0.4,
             0.0, 0.8660254037844386)
            .finished();
    Eigen::Vector3d origin(
        999.9019237886467, -1996.5358983848623, 294.9019237886467);
    double checksum = 0.0;

    const auto started = std::chrono::steady_clock::now();
    for (std::size_t index = 0; index < iterations; ++index) {
        origin.x() += static_cast<double>(index & 1U) * 1.0e-12;
        const double range = normal.dot(plane_origin - origin) /
                             normal.dot(normal);
        const Eigen::Vector3d world = origin + range * normal;
        const Eigen::Vector2d coordinates = basis.transpose() *
                                             (world - plane_origin);
        checksum += range + coordinates.x() + coordinates.y();
    }
    const auto elapsed = std::chrono::steady_clock::now() - started;
    const double nanoseconds = static_cast<double>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed).count());

    const sightline::Plane production_plane{
        {plane_origin.x(), plane_origin.y(), plane_origin.z()},
        {normal.x(), normal.y(), normal.z()},
        {basis(0, 0), basis(1, 0), basis(2, 0)},
        {basis(0, 1), basis(1, 1), basis(2, 1)}};
    const sightline::PlaneIntersection reference =
        sightline::intersect_forward_plane(
            production_plane,
            {999.9019237886467, -1996.5358983848623, 294.9019237886467},
            production_plane.normal);
    if (!reference.valid() || std::abs(reference.range - 5.0) > 1.0e-12 ||
        std::abs(reference.plane.x - 2.0) > 1.0e-12 ||
        std::abs(reference.plane.y + 3.0) > 1.0e-12) {
        return 1;
    }

    std::cout << std::setprecision(17)
              << "backend=eigen_5_cpu iterations=" << iterations
              << " nanoseconds_per_intersection="
              << nanoseconds / static_cast<double>(iterations)
              << " checksum=" << checksum << '\n';
    return 0;
}

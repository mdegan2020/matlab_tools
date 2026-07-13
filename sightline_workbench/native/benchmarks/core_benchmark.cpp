#include "sightline/core.hpp"

#include <chrono>
#include <cstddef>
#include <iomanip>
#include <iostream>

int main() {
    constexpr std::size_t iterations = 1'000'000U;
    const sightline::Plane plane{
        {1000.0, -2000.0, 300.0},
        {0.5196152422706632, -0.6928203230275509, 0.5},
        {0.8, 0.6, 0.0},
        {-0.3, 0.4, 0.8660254037844386}};
    const sightline::Vec3d direction = plane.normal;
    sightline::Vec3d origin{
        999.9019237886467, -1996.5358983848623, 294.9019237886467};
    double checksum = 0.0;

    const auto started = std::chrono::steady_clock::now();
    for (std::size_t index = 0; index < iterations; ++index) {
        origin.x += static_cast<double>(index & 1U) * 1.0e-12;
        const sightline::PlaneIntersection result =
            sightline::intersect_forward_plane(plane, origin, direction);
        if (!result.valid()) {
            return 1;
        }
        checksum += result.range + result.plane.x + result.plane.y;
    }
    const auto elapsed = std::chrono::steady_clock::now() - started;
    const double nanoseconds = static_cast<double>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed).count());

    std::cout << std::setprecision(17)
              << "backend=sightline_std_cpu iterations=" << iterations
              << " nanoseconds_per_intersection="
              << nanoseconds / static_cast<double>(iterations)
              << " checksum=" << checksum << '\n';
    return 0;
}

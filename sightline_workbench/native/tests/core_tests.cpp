#include "sightline/c_api.h"
#include "sightline/core.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct FixtureRow final {
    std::string case_id;
    sightline::Plane plane;
    sightline::Vec3d origin;
    sightline::Vec3d direction;
    double expected_range;
    sightline::Vec3d expected_world;
    sightline::Vec2d expected_plane;
    bool valid;
    sightline::IntersectionStatus expected_status;
};

[[nodiscard]] std::vector<std::string> split(const std::string& line) {
    std::vector<std::string> values;
    std::stringstream stream(line);
    std::string value;
    while (std::getline(stream, value, ',')) {
        values.push_back(value);
    }
    return values;
}

[[nodiscard]] sightline::IntersectionStatus parse_status(
    const std::string& value) {
    if (value == "ok") {
        return sightline::IntersectionStatus::ok;
    }
    if (value == "parallel") {
        return sightline::IntersectionStatus::parallel;
    }
    if (value == "behind") {
        return sightline::IntersectionStatus::behind_origin;
    }
    throw std::runtime_error("Unknown fixture status: " + value);
}

[[nodiscard]] std::vector<FixtureRow> read_fixture() {
    std::ifstream input(SIGHTLINE_FIXTURE_PATH);
    if (!input) {
        throw std::runtime_error("Cannot open golden fixture");
    }
    std::string line;
    std::getline(input, line);
    std::vector<FixtureRow> rows;
    while (std::getline(input, line)) {
        if (line.empty()) {
            continue;
        }
        const std::vector<std::string> values = split(line);
        if (values.size() != 27U) {
            throw std::runtime_error("Unexpected golden fixture column count");
        }
        const auto number = [&values](std::size_t index) {
            return std::stod(values.at(index));
        };
        rows.push_back({
            values.at(0),
            {{number(1), number(2), number(3)},
             {number(4), number(5), number(6)},
             {number(7), number(8), number(9)},
             {number(10), number(11), number(12)}},
            {number(13), number(14), number(15)},
            {number(16), number(17), number(18)},
            number(19),
            {number(20), number(21), number(22)},
            {number(23), number(24)},
            values.at(25) == "1",
            parse_status(values.at(26))});
    }
    return rows;
}

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void require_near(double actual, double expected, double tolerance,
                  const std::string& message) {
    const double scale = std::max({1.0, std::abs(actual), std::abs(expected)});
    require(std::abs(actual - expected) <= tolerance * scale, message);
}

sl_plane to_c(const sightline::Plane& plane) {
    const auto vector = [](sightline::Vec3d value) {
        return sl_vec3d{value.x, value.y, value.z};
    };
    return {vector(plane.origin), vector(plane.normal), vector(plane.basis_x),
            vector(plane.basis_y)};
}

void run_fixture_tests() {
    const std::vector<FixtureRow> rows = read_fixture();
    require(rows.size() == 5U, "Golden fixture must contain five cases");
    for (const FixtureRow& row : rows) {
        require(sightline::is_valid_plane(row.plane),
                row.case_id + ": fixture plane is invalid");
        const sightline::PlaneIntersection result =
            sightline::intersect_forward_plane(
                row.plane, row.origin, row.direction);
        require(result.status == row.expected_status,
                row.case_id + ": status mismatch");
        require(result.valid() == row.valid,
                row.case_id + ": validity mismatch");
        if (!row.valid) {
            require(std::isnan(result.range),
                    row.case_id + ": invalid range must be NaN");
            continue;
        }
        require_near(result.range, row.expected_range, 1.0e-12,
                     row.case_id + ": range mismatch");
        require_near(result.world.x, row.expected_world.x, 1.0e-12,
                     row.case_id + ": world x mismatch");
        require_near(result.world.y, row.expected_world.y, 1.0e-12,
                     row.case_id + ": world y mismatch");
        require_near(result.world.z, row.expected_world.z, 1.0e-12,
                     row.case_id + ": world z mismatch");
        require_near(result.plane.x, row.expected_plane.x, 1.0e-12,
                     row.case_id + ": plane x mismatch");
        require_near(result.plane.y, row.expected_plane.y, 1.0e-12,
                     row.case_id + ": plane y mismatch");
        const sightline::Vec3d reconstructed =
            sightline::reconstruct_plane(row.plane, result.plane);
        require_near(reconstructed.x, result.world.x, 1.0e-12,
                     row.case_id + ": reconstructed x mismatch");
        require_near(reconstructed.y, result.world.y, 1.0e-12,
                     row.case_id + ": reconstructed y mismatch");
        require_near(reconstructed.z, result.world.z, 1.0e-12,
                     row.case_id + ": reconstructed z mismatch");
    }
}

void run_c_api_test() {
    const std::vector<FixtureRow> rows = read_fixture();
    const FixtureRow& row = rows.front();
    const sl_plane plane = to_c(row.plane);
    const sl_vec3d origin{row.origin.x, row.origin.y, row.origin.z};
    const sl_vec3d direction{
        row.direction.x, row.direction.y, row.direction.z};
    sl_plane_intersection result{};
    const sl_intersection_status status = sl_intersect_forward_plane(
        &plane, origin, direction, 1.0e-12, &result);
    require(status == SL_INTERSECTION_OK, "C ABI status mismatch");
    require_near(result.range, row.expected_range, 1.0e-12,
                 "C ABI range mismatch");
    require(std::string(sl_version()) == "0.1.0", "C ABI version mismatch");
    require(sl_intersect_forward_plane(
                nullptr, origin, direction, 1.0e-12, &result) ==
                SL_INTERSECTION_INVALID_INPUT,
            "C ABI null plane must fail closed");
}

void run_invalid_plane_test() {
    sightline::Plane invalid{
        {0.0, 0.0, 0.0},
        {0.0, 0.0, 1.0},
        {1.0, 0.0, 0.0},
        {1.0, 0.0, 0.0}};
    require(!sightline::is_valid_plane(invalid),
            "Duplicate plane axes must be rejected");
    const sightline::PlaneIntersection result =
        sightline::intersect_forward_plane(
            invalid, {0.0, 0.0, 1.0}, {0.0, 0.0, -1.0});
    require(result.status == sightline::IntersectionStatus::invalid_input,
            "Invalid plane must fail closed");

    const sightline::Plane valid{
        {0.0, 0.0, 0.0},
        {0.0, 0.0, 1.0},
        {1.0, 0.0, 0.0},
        {0.0, 1.0, 0.0}};
    const sightline::PlaneIntersection nonunit =
        sightline::intersect_forward_plane(
            valid, {0.0, 0.0, 1.0}, {0.0, 0.0, -2.0});
    require(nonunit.status == sightline::IntersectionStatus::invalid_input,
            "Nonunit ray direction must fail closed");
}

}  // namespace

int main() {
    try {
        run_fixture_tests();
        run_c_api_test();
        run_invalid_plane_test();
        std::cout << "SIGHTLINE_NATIVE_TESTS=PASS fixture_cases=5\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << "SIGHTLINE_NATIVE_TESTS=FAIL message=" << exception.what()
                  << '\n';
        return 1;
    }
}

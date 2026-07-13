#include <ceres/ceres.h>

#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <vector>

namespace {

struct AngleResidual final {
    explicit AngleResidual(double observation) : observation_(observation) {}

    template <typename Scalar>
    bool operator()(const Scalar* const angle, Scalar* residual) const {
        residual[0] = angle[0] - Scalar(observation_);
        return true;
    }

private:
    double observation_;
};

}  // namespace

int main() {
    constexpr double expected_angle = 0.0125;
    std::vector<double> observations;
    observations.reserve(200U);
    for (int index = 0; index < 100; ++index) {
        const double perturbation = 1.0e-4 * static_cast<double>(index + 1);
        observations.push_back(expected_angle - perturbation);
        observations.push_back(expected_angle + perturbation);
    }

    double angle = 0.0;
    ceres::Problem problem;
    for (double observation : observations) {
        auto* cost = new ceres::AutoDiffCostFunction<AngleResidual, 1, 1>(
            new AngleResidual(observation));
        problem.AddResidualBlock(cost, new ceres::HuberLoss(0.05), &angle);
    }
    ceres::Solver::Options options;
    options.linear_solver_type = ceres::DENSE_QR;
    options.max_num_iterations = 20;
    options.num_threads = 1;
    options.minimizer_progress_to_stdout = false;
    ceres::Solver::Summary summary;
    const auto started = std::chrono::steady_clock::now();
    ceres::Solve(options, &problem, &summary);
    const auto elapsed = std::chrono::steady_clock::now() - started;
    const double microseconds = static_cast<double>(
        std::chrono::duration_cast<std::chrono::microseconds>(elapsed).count());

    if (!summary.IsSolutionUsable() ||
        std::abs(angle - expected_angle) > 1.0e-10) {
        return 1;
    }
    std::cout << std::setprecision(17)
              << "backend=ceres_2_2_cpu observations=" << observations.size()
              << " solved_angle=" << angle
              << " solve_microseconds=" << microseconds
              << " iterations=" << summary.iterations.size() << '\n';
    return 0;
}

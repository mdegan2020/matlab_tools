cmake_minimum_required(VERSION 3.25)

project(SightlineNative
    VERSION 0.1.0
    DESCRIPTION "Portable CPU reference for Sightline geometry and parity"
    LANGUAGES C CXX)

include(CTest)
include(FetchContent)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

option(SIGHTLINE_BUILD_TESTS "Build independent native tests" ON)
option(SIGHTLINE_BUILD_BENCHMARKS "Build non-gating CPU microbenchmarks" ON)
option(SIGHTLINE_ENABLE_EIGEN_PROBE "Build the Eigen parity/benchmark probe" OFF)
option(SIGHTLINE_FETCH_EIGEN "Fetch the reviewed Eigen release for its probe" OFF)
option(SIGHTLINE_ENABLE_CERES_PROBE "Build the Ceres attitude-solve probe" OFF)
option(SIGHTLINE_WARNINGS_AS_ERRORS "Treat Sightline compiler warnings as errors" ON)
option(SIGHTLINE_ENABLE_SANITIZERS "Enable address/undefined sanitizers when supported" OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(SightlineWarnings)

add_library(sightline_core STATIC
    src/c_api.cpp
    src/core.cpp)
add_library(Sightline::core ALIAS sightline_core)

target_compile_features(sightline_core PUBLIC cxx_std_17)
target_include_directories(sightline_core
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_link_libraries(sightline_core
    PRIVATE $<BUILD_INTERFACE:sightline_warnings>)
set_target_properties(sightline_core PROPERTIES
    CXX_EXTENSIONS OFF
    EXPORT_NAME core
    POSITION_INDEPENDENT_CODE ON)
sightline_enable_sanitizers(sightline_core)

if(SIGHTLINE_BUILD_TESTS)
    add_executable(sightline_core_tests tests/core_tests.cpp)
    target_link_libraries(sightline_core_tests
        PRIVATE Sightline::core sightline_warnings)
    target_compile_definitions(sightline_core_tests PRIVATE
        "SIGHTLINE_FIXTURE_PATH=\"${CMAKE_CURRENT_SOURCE_DIR}/fixtures/geometry_plane_intersections.csv\"")
    sightline_enable_sanitizers(sightline_core_tests)
    add_test(NAME sightline_core_tests COMMAND sightline_core_tests)

    add_executable(sightline_c_api_smoke tests/c_api_smoke.c)
    target_link_libraries(sightline_c_api_smoke
        PRIVATE Sightline::core sightline_warnings)
    set_target_properties(sightline_c_api_smoke PROPERTIES
        LINKER_LANGUAGE CXX)
    sightline_enable_sanitizers(sightline_c_api_smoke)
    add_test(NAME sightline_c_api_smoke COMMAND sightline_c_api_smoke)
endif()

if(SIGHTLINE_BUILD_BENCHMARKS)
    add_executable(sightline_core_benchmark benchmarks/core_benchmark.cpp)
    target_link_libraries(sightline_core_benchmark
        PRIVATE Sightline::core sightline_warnings)
    sightline_enable_sanitizers(sightline_core_benchmark)
endif()

if(SIGHTLINE_ENABLE_EIGEN_PROBE)
    find_package(Eigen3 5.0 CONFIG QUIET)
    if(NOT TARGET Eigen3::Eigen AND SIGHTLINE_FETCH_EIGEN)
        FetchContent_Declare(eigen
            URL https://gitlab.com/libeigen/eigen/-/archive/5.0.1/eigen-5.0.1.tar.gz
            URL_HASH SHA256=e9c326dc8c05cd1e044c71f30f1b2e34a6161a3b6ecf445d56b53ff1669e3dec
            DOWNLOAD_EXTRACT_TIMESTAMP FALSE
            SYSTEM)
        set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
        set(EIGEN_BUILD_TESTING OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(eigen)
    endif()
    if(NOT TARGET Eigen3::Eigen)
        message(FATAL_ERROR
            "Eigen probe requested but Eigen3::Eigen is unavailable; install Eigen 5.0.1 or enable SIGHTLINE_FETCH_EIGEN")
    endif()
    add_executable(sightline_eigen_probe benchmarks/eigen_geometry_probe.cpp)
    target_link_libraries(sightline_eigen_probe
        PRIVATE Sightline::core Eigen3::Eigen sightline_warnings)
    sightline_enable_sanitizers(sightline_eigen_probe)
    if(SIGHTLINE_BUILD_TESTS)
        add_test(NAME sightline_eigen_probe COMMAND sightline_eigen_probe)
    endif()
endif()

if(SIGHTLINE_ENABLE_CERES_PROBE)
    find_package(Ceres 2.2 CONFIG REQUIRED)
    add_executable(sightline_ceres_probe benchmarks/ceres_attitude_probe.cpp)
    target_link_libraries(sightline_ceres_probe
        PRIVATE Ceres::ceres sightline_warnings)
    sightline_enable_sanitizers(sightline_ceres_probe)
    if(SIGHTLINE_BUILD_TESTS)
        add_test(NAME sightline_ceres_probe COMMAND sightline_ceres_probe)
    endif()
endif()

install(TARGETS sightline_core
    EXPORT SightlineNativeTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT SightlineNativeTargets
    FILE SightlineNativeTargets.cmake
    NAMESPACE Sightline::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/SightlineNative)

configure_package_config_file(
    cmake/SightlineNativeConfig.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/SightlineNativeConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/SightlineNative)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/SightlineNativeConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/SightlineNativeConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/SightlineNativeConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/SightlineNative)

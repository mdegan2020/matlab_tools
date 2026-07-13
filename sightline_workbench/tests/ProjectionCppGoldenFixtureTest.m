classdef ProjectionCppGoldenFixtureTest < matlab.unittest.TestCase
    %ProjectionCppGoldenFixtureTest MATLAB/native public geometry parity.

    properties (SetAccess = private)
        Root (1, 1) string
        CsvPath (1, 1) string
        ManifestPath (1, 1) string
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            testCase.Root = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.CsvPath = fullfile(testCase.Root, "native", ...
                "fixtures", "geometry_plane_intersections.csv");
            testCase.ManifestPath = fullfile(testCase.Root, "native", ...
                "fixtures", "geometry_plane_intersections.json");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.Root, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.Root, "scripts")));
        end
    end

    methods (Test)
        function testCommittedFixtureMatchesProductionGeometry(testCase)
            fixture = readtable(testCase.CsvPath, TextType="string");
            testCase.verifyEqual(height(fixture), 5);

            for index = 1:height(fixture)
                plane = ProjectionCppGoldenFixtureTest.plane(fixture, index);
                origin = ProjectionCppGoldenFixtureTest.vector( ...
                    fixture, index, "origin");
                direction = ProjectionCppGoldenFixtureTest.vector( ...
                    fixture, index, "direction");
                status = fixture.status(index);
                denominator = plane.VN.' * direction;
                if status == "parallel"
                    testCase.verifyLessThanOrEqual(abs(denominator), 1e-12);
                    testCase.verifyError(@() PlanarProjection.intersectPlane( ...
                        direction, origin, plane), ...
                        "PlanarProjection:parallelRay");
                    continue
                end

                [world, coordinates] = PlanarProjection.intersectPlane( ...
                    direction, origin, plane);
                range = dot(world - origin, direction) / dot(direction, direction);
                if status == "behind"
                    testCase.verifyLessThanOrEqual(range, 0);
                    continue
                end

                expectedWorld = ProjectionCppGoldenFixtureTest.vector( ...
                    fixture, index, "expected_world");
                expectedPlane = [fixture.expected_plane_x(index); ...
                    fixture.expected_plane_y(index)];
                testCase.verifyGreaterThan(range, 0);
                testCase.verifyEqual(range, fixture.expected_range(index), ...
                    AbsTol=1e-11, RelTol=1e-12);
                testCase.verifyEqual(world, expectedWorld, ...
                    AbsTol=1e-11, RelTol=1e-12);
                testCase.verifyEqual(coordinates, expectedPlane, ...
                    AbsTol=1e-11, RelTol=1e-12);
            end
        end

        function testExporterReproducesCommittedFixture(testCase)
            path = string(tempname) + ".csv";
            cleanup = onCleanup(@() delete(path));
            records = exportCppGeometryGoldenFixture(path);
            generated = readtable(path, TextType="string");
            committed = readtable(testCase.CsvPath, TextType="string");

            testCase.verifyEqual(numel(records), height(committed));
            testCase.verifyEqual(generated, committed);
            clear cleanup
        end

        function testManifestFreezesTranslationContract(testCase)
            manifest = jsondecode(fileread(testCase.ManifestPath));

            testCase.verifyEqual(string(manifest.format), ...
                "SightlineNativeGoldenFixture");
            testCase.verifyEqual(manifest.version, 1);
            testCase.verifyEqual(string(manifest.precision), ...
                "IEEE-754 binary64");
            testCase.verifyEqual(string(manifest.units.world), "meters");
            testCase.verifyEqual(string( ...
                manifest.coordinate_contract.ray_domain), "forward-only");
            testCase.verifyEqual(manifest.tolerances.parallel_denominator, ...
                1e-12);
            testCase.verifyEqual(string(manifest.invalid_status), ...
                ["parallel"; "behind"]);
        end
    end

    methods (Static, Access = private)
        function plane = plane(fixture, index)
            plane = struct(P0=ProjectionCppGoldenFixtureTest.vector( ...
                fixture, index, "p0"), ...
                VN=ProjectionCppGoldenFixtureTest.vector( ...
                fixture, index, "normal"), ...
                basis=[ProjectionCppGoldenFixtureTest.vector( ...
                fixture, index, "basis_x") ...
                ProjectionCppGoldenFixtureTest.vector( ...
                fixture, index, "basis_y")]);
            PlanarProjection.validatePlane(plane);
        end

        function value = vector(fixture, index, prefix)
            value = [fixture.(prefix + "_x")(index); ...
                fixture.(prefix + "_y")(index); ...
                fixture.(prefix + "_z")(index)];
        end
    end
end

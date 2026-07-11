classdef ProjectionDenseSurfaceSyntheticTruthTest < matlab.unittest.TestCase
    %ProjectionDenseSurfaceSyntheticTruthTest Tests compact terrain and motion truth.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "tests")));
        end
    end

    methods (Test)
        function testTerrainEnforcesExtremaAndRemainsSmoothAsymmetric(testCase)
            [config, plan] = ProjectionDenseSurfaceSyntheticTestSupport.plan();
            terrain = ProjectionDenseSurfaceSyntheticTerrain.create(config, plan);
            [xGrid, yGrid] = ...
                ProjectionDenseSurfaceSyntheticTruthTest.terrainGrid(terrain, 257);

            height = ProjectionDenseSurfaceSyntheticTerrain.height( ...
                terrain, xGrid, yGrid);
            center = terrain.CenterMeters;
            positive = ProjectionDenseSurfaceSyntheticTerrain.height( ...
                terrain, center(1) + 17, center(2) + 9);
            negative = ProjectionDenseSurfaceSyntheticTerrain.height( ...
                terrain, center(1) - 17, center(2) + 9);
            neighborDifference = max(abs(diff(height, 1, 1)), [], "all");

            testCase.verifyEqual(min(height, [], "all"), ...
                config.terrain.minimum_height_meters, AbsTol=1e-10);
            testCase.verifyEqual(max(height, [], "all"), ...
                config.terrain.maximum_height_meters, AbsTol=1e-10);
            testCase.verifyLessThan(neighborDifference, ...
                config.terrain.maximum_height_meters - ...
                config.terrain.minimum_height_meters);
            testCase.verifyGreaterThan(abs(positive - negative), 1e-6);
        end

        function testFirstHitClassifiesOccludedTerrain(testCase)
            [config, plan] = ProjectionDenseSurfaceSyntheticTestSupport.plan();
            truth = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);
            [origin, point] = ...
                ProjectionDenseSurfaceSyntheticTruthTest.findOccludedPoint(truth);
            displacement = point - origin;
            targetRange = norm(displacement);

            [hitPoint, hitStatus, hitRange] = ...
                ProjectionDenseSurfaceSyntheticTerrain.intersectRays( ...
                truth.Terrain, origin, displacement);
            visibility = ...
                ProjectionDenseSurfaceSyntheticTerrain.classifyVisibility( ...
                truth.Terrain, origin, point, 0.1);

            testCase.verifyEqual(hitStatus, "visibleTerrain");
            testCase.verifyEqual(visibility, "terrainOcclusion");
            testCase.verifyLessThan(hitRange, targetRange - 0.1);
            testCase.verifyEqual(hitPoint(3), ...
                ProjectionDenseSurfaceSyntheticTerrain.height( ...
                truth.Terrain, hitPoint(1), hitPoint(2)), AbsTol=1e-5);
        end

        function testTrajectoryIsRepeatableContinuousAndRngLocal(testCase)
            originalRng = rng;
            testCase.addTeardown(@() rng(originalRng));
            [config, plan] = ProjectionDenseSurfaceSyntheticTestSupport.plan();
            rng(31, "twister");
            expectedRandom = rand(1, 4);
            rng(31, "twister");

            first = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);
            actualRandom = rand(1, 4);
            second = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);
            centerTime = first.Views(2).CenterTimeSeconds;
            state = ProjectionDenseSurfaceSyntheticTruth.sampleTrajectory( ...
                first, centerTime + [-1e-4 0 1e-4]);

            testCase.verifyEqual(actualRandom, expectedRandom);
            testCase.verifyEqual(first.Trajectory, second.Trajectory);
            testCase.verifyLessThan(max(vecnorm(diff(state.Position, 1, 2))), 0.1);
            testCase.verifyGreaterThan(state.Position(1, 3), state.Position(1, 1));
            testCase.verifyTrue(all(isfinite(state.Velocity), "all"));
        end

        function testCompactTruthSupportsGridAndObservationSampling(testCase)
            [config, plan] = ProjectionDenseSurfaceSyntheticTestSupport.plan();
            truth = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);
            rowIndices = [1 51 101];
            columnIndices = [1 151 301];

            [origins, vectors] = ProjectionDenseSurfaceSyntheticTruth.sampleGridRays( ...
                truth, 1, rowIndices, columnIndices);
            [pairedOrigins, pairedVectors] = ...
                ProjectionDenseSurfaceSyntheticTruth.sampleRays( ...
                truth, 1, rowIndices, columnIndices);
            flattenedVectors = reshape(vectors, 3, []);
            diagonalIndices = 1 + (0:(numel(rowIndices) - 1)) * ...
                (numel(rowIndices) + 1);
            [points, status, ranges] = ...
                ProjectionDenseSurfaceSyntheticTruth.intersectObservations( ...
                truth, 1, [25.5 51 76.5], [80.25 151 221.75]);
            truthInfo = whos("truth");
            fullXyzBytes = prod(truth.ImageSize) * 3 * 8 * numel(truth.Views);

            testCase.verifySize(origins, [3 numel(columnIndices)]);
            testCase.verifySize(vectors, ...
                [3 numel(rowIndices) numel(columnIndices)]);
            testCase.verifyEqual(origins, pairedOrigins, AbsTol=1e-12);
            testCase.verifyEqual(flattenedVectors(:, diagonalIndices), ...
                pairedVectors, AbsTol=1e-12);
            testCase.verifyEqual(squeeze(vecnorm(vectors, 2, 1)), ...
                ones(numel(rowIndices), numel(columnIndices)), AbsTol=1e-12);
            testCase.verifyEqual(status, repmat("visibleTerrain", 1, 3));
            testCase.verifyTrue(all(isfinite(points), "all"));
            testCase.verifyTrue(all(ranges > 0));
            testCase.verifyTrue(truth.CompactOnDemand);
            testCase.verifyFalse(truth.ContainsPerPixelXyz);
            testCase.verifyLessThan(truthInfo.bytes, fullXyzBytes);
            testCase.verifyFalse( ...
                ProjectionDenseSurfaceSyntheticTruthTest.containsFunctionHandle( ...
                truth));
        end

        function testBandCycleAndVisibilityVocabularyAreExplicit(testCase)
            [config, plan] = ProjectionDenseSurfaceSyntheticTestSupport.plan();

            truth = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);

            testCase.verifyEqual([truth.Views.SourceBand], ...
                config.image.source_band_sequence);
            testCase.verifyEqual(truth.VisibilityStatuses, ...
                ["visibleTerrain" "terrainOcclusion" ...
                "textureCoverageFailure" "invalidGeometry"]);
            testCase.verifyTrue(truth.OcclusionAudit.Passed);
            testCase.verifyGreaterThan(truth.OcclusionAudit.OccludedCount, 0);
        end

        function testViewerMetadataContainsNoTruthPayload(testCase)
            [config, plan] = ProjectionDenseSurfaceSyntheticTestSupport.plan();
            truth = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);

            metadata = ProjectionDenseSurfaceSyntheticTruth.sceneMetadata(truth);

            testCase.verifyFalse(metadata.TruthIncluded);
            testCase.verifyEqual(metadata.GeometryRole, "reported-only");
            testCase.verifyFalse(isfield(metadata, "Terrain"));
            testCase.verifyFalse(isfield(metadata, "Trajectory"));
            testCase.verifyFalse(isfield(metadata, "Views"));
        end
    end

    methods (Static, Access = private)
        function [xGrid, yGrid] = terrainGrid(terrain, gridSize)
            x = linspace(terrain.BoundsMeters(1), terrain.BoundsMeters(2), gridSize);
            y = linspace(terrain.BoundsMeters(3), terrain.BoundsMeters(4), gridSize);
            [xGrid, yGrid] = meshgrid(x, y);
        end

        function [origin, point] = findOccludedPoint(truth)
            [xGrid, yGrid] = ...
                ProjectionDenseSurfaceSyntheticTruthTest.terrainGrid( ...
                truth.Terrain, 49);
            zGrid = ProjectionDenseSurfaceSyntheticTerrain.height( ...
                truth.Terrain, xGrid, yGrid);
            points = [xGrid(:).'; yGrid(:).'; zGrid(:).'];
            centerTimes = [truth.Views.CenterTimeSeconds];
            state = ProjectionDenseSurfaceSyntheticTruth.sampleTrajectory( ...
                truth, centerTimes);
            for viewIndex = 1:numel(centerTimes)
                origins = repmat(state.Position(:, viewIndex), 1, size(points, 2));
                status = ProjectionDenseSurfaceSyntheticTerrain.classifyVisibility( ...
                    truth.Terrain, origins, points, 0.1);
                match = find(status == "terrainOcclusion", 1, "first");
                if ~isempty(match)
                    origin = origins(:, match);
                    point = points(:, match);
                    return
                end
            end
            error("ProjectionDenseSurfaceSyntheticTruthTest:noOcclusion", ...
                "Public terrain fixture did not contain an occluded point.");
        end

        function tf = containsFunctionHandle(value)
            if isa(value, "function_handle")
                tf = true;
                return
            end
            if isstruct(value)
                fields = fieldnames(value);
                tf = false;
                for elementIndex = 1:numel(value)
                    for fieldIndex = 1:numel(fields)
                        tf = tf || ...
                            ProjectionDenseSurfaceSyntheticTruthTest. ...
                            containsFunctionHandle(value(elementIndex).(fields{fieldIndex}));
                    end
                end
                return
            end
            if iscell(value)
                tf = any(cellfun( ...
                    @ProjectionDenseSurfaceSyntheticTruthTest.containsFunctionHandle, ...
                    value));
                return
            end
            tf = false;
        end
    end
end

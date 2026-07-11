classdef ProjectionDenseSurfaceSyntheticPlannerTest < matlab.unittest.TestCase
    %ProjectionDenseSurfaceSyntheticPlannerTest Tests synthetic collection planning.

    properties (Constant)
        Tol = 1e-9
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testLoadValidatesSchemaAndResolvesRuntimePaths(testCase)
            root = ProjectionDenseSurfaceSyntheticPlannerTest.makeTemporaryRoot( ...
                testCase);
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();
            configPath = ProjectionDenseSurfaceSyntheticPlannerTest.writeConfig( ...
                root, config);

            [loaded, context] = ProjectionDenseSurfaceSyntheticConfig.load(configPath);

            testCase.verifyEqual(loaded.schema_version, 1);
            testCase.verifyTrue(isfile(context.SourceImagePath));
            testCase.verifyEqual(context.ProjectRoot, string(root));
            testCase.verifyTrue(startsWith(context.OutputDirectory, string(root)));
        end

        function testValidationRejectsSchemaDrift(testCase)
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();
            config.image.unapproved_field = true;

            testCase.verifyError( ...
                @() ProjectionDenseSurfaceSyntheticConfig.validate(config), ...
                "ProjectionDenseSurfaceSyntheticConfig:schemaMismatch");
        end

        function testFrameTransformAndGimbalOrderAreExplicit(testCase)
            transform = ...
                ProjectionDenseSurfaceSyntheticPlanner.bodyToWorldMatrix();
            pitchRay = ProjectionDenseSurfaceSyntheticPlanner.boresightRay(0, 5);
            rightRay = ProjectionDenseSurfaceSyntheticPlanner.boresightRay(-30, 0);
            composed = ProjectionDenseSurfaceSyntheticPlanner.gimbalRotation(-30, 5);

            testCase.verifyEqual(transform, diag([1 1 -1]));
            testCase.verifyGreaterThan(pitchRay(1), 0);
            testCase.verifyGreaterThan(rightRay(2), 0);
            testCase.verifyEqual(composed * [0; 0; 1], ...
                ProjectionDenseSurfaceSyntheticPlanner.gimbalRotation(-30, 0) * ...
                ProjectionDenseSurfaceSyntheticPlanner.gimbalRotation(0, 5) * ...
                [0; 0; 1], ...
                AbsTol=ProjectionDenseSurfaceSyntheticPlannerTest.Tol);
        end

        function testFeasiblePlanReportsDerivedRelationships(testCase)
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();

            report = ProjectionDenseSurfaceSyntheticPlanner.plan( ...
                config, [128 136 3]);
            projectedGsd = reshape([report.Views.ProjectedGsdMeters], 2, []).';
            contributions = [report.Views.PlatformAdvanceMetersPerColumn].' + ...
                [report.Views.GimbalAdvanceMetersPerColumn].';

            testCase.verifyTrue(report.Feasible, report.Explanation);
            testCase.verifyEqual(numel(report.Views), config.image.view_count);
            testCase.verifyEqual(contributions, projectedGsd(:, 2), ...
                AbsTol=ProjectionDenseSurfaceSyntheticPlannerTest.Tol);
            testCase.verifyGreaterThan([report.Views.PitchFieldOfRegardMarginDegrees], 0);
            testCase.verifyGreaterThanOrEqual( ...
                min(report.AchievedSceneCenterSeparationsDegrees), ...
                config.collection_planner.desired_scene_center_separation_degrees);
            testCase.verifyEqual(report.AcquisitionDurationSeconds, ...
                config.image.columns / config.image.scan_rate_lines_per_second, ...
                AbsTol=ProjectionDenseSurfaceSyntheticPlannerTest.Tol);
        end

        function testPitchInfeasibilityIsExplainable(testCase)
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();
            config.gimbal.pitch_field_of_regard_degrees = [-2 2];
            config.gimbal.maximum_initial_forward_pitch_degrees = 1;

            report = ProjectionDenseSurfaceSyntheticPlanner.plan(config, [128 136 3]);

            testCase.verifyFalse(report.Feasible);
            testCase.verifyEqual(report.FirstViolation, "pitchFieldOfRegard");
            testCase.verifyNotEmpty(report.Explanation);
            testCase.verifyTrue(isfield(report.NearestCandidate, ...
                "MinimumPitchMarginDegrees"));
        end

        function testTextureGrowthInfeasibilityIsExplainable(testCase)
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();
            config.sampling.minimum_reflection_tiles_rows = 1;
            config.sampling.minimum_reflection_tiles_columns = 1;
            config.sampling.maximum_reflection_tiles_rows = 1;
            config.sampling.maximum_reflection_tiles_columns = 1;

            report = ProjectionDenseSurfaceSyntheticPlanner.plan(config, [12 14 3]);

            testCase.verifyFalse(report.Feasible);
            testCase.verifyEqual(report.FirstViolation, "textureGridGrowth");
            testCase.verifyGreaterThan(max(report.RequiredReflectionTileCount), 1);
        end

        function testDisallowedScheduleExpansionFailsExplicitly(testCase)
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();
            config.collection_planner.allow_separation_expansion = false;

            report = ProjectionDenseSurfaceSyntheticPlanner.plan(config, [128 136 3]);

            testCase.verifyFalse(report.Feasible);
            testCase.verifyEqual(report.FirstViolation, "constantGapSchedule");
            testCase.verifyTrue(report.SeparationExpanded);
        end

        function testMissingSourceBandIsRejected(testCase)
            config = ProjectionDenseSurfaceSyntheticTestSupport.config();

            testCase.verifyError( ...
                @() ProjectionDenseSurfaceSyntheticPlanner.plan(config, [128 136 2]), ...
                "ProjectionDenseSurfaceSyntheticPlanner:missingSourceBand");
        end
    end

    methods (Static, Access = private)
        function root = makeTemporaryRoot(testCase)
            root = tempname;
            mkdir(root);
            mkdir(fullfile(root, "config"));
            mkdir(fullfile(root, "test_data"));
            testCase.addTeardown(@() rmdir(root, "s"));
            source = uint8(mod(reshape(0:(16 * 18 * 3 - 1), 16, 18, 3), 251));
            imwrite(source, fullfile(root, "test_data", "public_texture.tif"));
        end

        function configPath = writeConfig(root, config)
            configPath = fullfile(root, "config", "public_config.json");
            fileId = fopen(configPath, "w");
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "%s", jsonencode(config, PrettyPrint=true));
            clear cleanup
        end

    end
end

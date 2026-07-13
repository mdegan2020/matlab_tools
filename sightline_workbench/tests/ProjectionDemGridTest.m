classdef ProjectionDemGridTest < matlab.unittest.TestCase
    %ProjectionDemGridTest S7 WGS84/datum/uncertainty ingestion tests.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testHaeGridNormalizesToReversibleSceneEnu(testCase)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            dem = ProjectionDemGrid.create(input);
            world = [dem.WorldX(10, 12); dem.WorldY(10, 12); ...
                dem.WorldZ(10, 12)];
            geodetic = ProjectionDemGrid.worldToGeodetic(dem, world);
            roundTrip = ProjectionDemGrid.geodeticToWorld(dem, geodetic);

            testCase.verifyEqual(dem.Format, "ProjectionDemGrid");
            testCase.verifyEqual(dem.HeightReferenceInput, "HAE");
            testCase.verifyEqual(dem.HeightReferenceWorking, "HAE");
            testCase.verifyEqual(dem.GeoidModel, "NONE");
            testCase.verifyEqual(roundTrip, world, AbsTol=1e-8);
            testCase.verifyTrue(dem.Transforms.Reversible);
            testCase.verifyFalse(dem.Diagnostics.RuntimeStateIncluded);
        end

        function testMslAndOmittedDtedReferenceUseExplicitEgm96(testCase)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            input.HeightReference = "MSL";
            input.GeoidModel = "EGM96";
            msl = ProjectionDemGrid.create(input);
            dtedInput = rmfield(input, ["HeightReference" "GeoidModel" ...
                "CallerAccuracy"]);
            dtedInput.DatasetKind = "DTED2";
            dted = ProjectionDemGrid.create(dtedInput);
            difference = msl.HaeHeightsMeters - msl.InputHeightsMeters;

            testCase.verifyEqual(difference(msl.BaseValidMask), ...
                msl.GeoidUndulationMeters(msl.BaseValidMask), AbsTol=1e-12);
            testCase.verifyEqual(msl.GeoidModel, "EGM96");
            testCase.verifyEqual(dted.HeightReferenceInput, "MSL");
            testCase.verifyEqual(dted.GeoidModel, "EGM96");
            testCase.verifyEqual(dted.DatumAssumption, ...
                "omittedDtedReferenceAssumedMslEgm96");
            testCase.verifyEqual(dted.Accuracy.Source, "dted2Default");
            testCase.verifyEqual([dted.Accuracy.CE90Meters ...
                dted.Accuracy.LE90Meters], [23 18]);
        end

        function testSentinelFiniteMaskAndExclusionDefineValidity(testCase)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            input.NoDataValue = -9999;
            input.HeightsMeters(1, 1) = -9999;
            input.HeightsMeters(1, 2) = NaN;
            input.ValidityMask = true(size(input.HeightsMeters));
            input.ValidityMask(1, 3) = false;
            input.ExclusionMask = false(size(input.HeightsMeters));
            input.ExclusionMask(1, 4) = true;
            dem = ProjectionDemGrid.create(input);

            testCase.verifyEqual(dem.Diagnostics.CellCount, 961);
            testCase.verifyEqual(dem.Diagnostics.BaseValidCellCount, 958);
            testCase.verifyEqual(dem.Diagnostics.ExcludedCellCount, 1);
            testCase.verifyEqual( ...
                dem.Diagnostics.RegistrationValidCellCount, 957);
            testCase.verifyFalse(dem.BaseValidMask(1, 1));
            testCase.verifyFalse(dem.BaseValidMask(1, 2));
            testCase.verifyFalse(dem.ValidMask(1, 4));
            testCase.verifyTrue(isnan(dem.HaeHeightsMeters(1, 1)));
        end

        function testAccuracyPrecedenceAndGaussianConversionAreExplicit(testCase)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            input.DatasetAccuracy = struct(CE90Meters=7, LE90Meters=8);
            caller = ProjectionDemGrid.create(input);
            input.CallerAccuracy = struct();
            dataset = ProjectionDemGrid.create(input);

            testCase.verifyEqual(caller.Accuracy.Source, "caller");
            testCase.verifyEqual([caller.Accuracy.CE90Meters ...
                caller.Accuracy.LE90Meters], [0.5 0.5]);
            testCase.verifyEqual(dataset.Accuracy.Source, "dataset");
            testCase.verifyEqual([dataset.Accuracy.CE90Meters ...
                dataset.Accuracy.LE90Meters], [7 8]);
            testCase.verifyEqual(caller.Accuracy.HorizontalSigmaMeters, ...
                0.5 / sqrt(-2 * log(0.1)), AbsTol=1e-14);
            testCase.verifyEqual(caller.Accuracy.VerticalSigmaMeters, ...
                0.5 / 1.64485362695147, AbsTol=1e-14);
            testCase.verifyEqual(caller.Accuracy.CellCorrelationAssumption, ...
                "datasetAccuracySharedAcrossCellsNotIndependent");
        end

        function testGenericGridWithoutAccuracyCannotRegister(testCase)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            input.CallerAccuracy = struct();
            dem = ProjectionDemGrid.create(input);
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            request.Dem = dem;

            testCase.verifyFalse(dem.Accuracy.Available);
            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationRequest.validate(request), ...
                "ProjectionSurfaceRegistrationRequest:missingDemUncertainty");
        end

        function testProjectWorldRotationAndOriginRemainReversible(testCase)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            angle = deg2rad(25);
            rotation = [cos(angle) -sin(angle) 0; ...
                sin(angle) cos(angle) 0; 0 0 1];
            input.SceneFrame.EnuToProjectWorldRotation = rotation;
            input.SceneFrame.ProjectWorldOriginMeters = [500; -200; 30];
            dem = ProjectionDemGrid.create(input);
            enu = [10 -5; 20 4; 3 2];
            world = ProjectionDemGrid.enuToWorld(dem, enu);
            roundTrip = ProjectionDemGrid.worldToEnu(dem, world);

            testCase.verifyEqual(roundTrip, enu, AbsTol=1e-12);
            testCase.verifyEqual(dem.Transforms.EnuToProjectWorldRotation, ...
                rotation, AbsTol=1e-14);
            testCase.verifyEqual(dem.Transforms.ProjectWorldOriginMeters, ...
                [500; -200; 30]);
        end

        function testDatumSchemaAndRuntimeValuesFailClosed(testCase)
            missing = ProjectionSurfaceRegistrationFixture.basicDemInput();
            missing.HeightReference = "";
            geoid = ProjectionSurfaceRegistrationFixture.basicDemInput();
            geoid.HeightReference = "MSL";
            geoid.GeoidModel = "EGM2008";
            mixed = ProjectionSurfaceRegistrationFixture.basicDemInput();
            mixed.GeoidModel = "EGM96";
            dem = ProjectionDemGrid.create( ...
                ProjectionSurfaceRegistrationFixture.basicDemInput());
            runtime = dem;
            runtime.Diagnostics.Callback = @() true;
            future = dem;
            future.Version = 2;

            testCase.verifyError(@() ProjectionDemGrid.create(missing), ...
                "ProjectionDemGrid:missingHeightReference");
            testCase.verifyError(@() ProjectionDemGrid.create(geoid), ...
                "ProjectionDemGrid:unsupportedGeoid");
            testCase.verifyError(@() ProjectionDemGrid.create(mixed), ...
                "ProjectionDemGrid:invalidDatum");
            testCase.verifyError(@() ProjectionDemGrid.validate(runtime), ...
                "ProjectionDemGrid:runtimeState");
            testCase.verifyError(@() ProjectionDemGrid.validate(future), ...
                "ProjectionDemGrid:unsupportedSchema");
        end
    end
end

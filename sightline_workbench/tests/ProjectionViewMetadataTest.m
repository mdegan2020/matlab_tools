classdef ProjectionViewMetadataTest < matlab.unittest.TestCase
    %ProjectionViewMetadataTest Tests stable identity and optional timing.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingViewer(testCase)
            delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline"));
            testCase.addTeardown(@() delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline")));
        end
    end

    methods (Test)
        function testGeneratedIdsRemainStableAcrossLayerReorder(testCase)
            scene = ProjectionViewMetadataTest.makeScene(3);
            originalIds = ProjectionViewMetadata.ids(scene);
            reordered = scene;
            reordered.layers = reordered.layers([3 1 2]);

            reorderedIds = ProjectionViewMetadata.ids(reordered);

            testCase.verifyEqual(reorderedIds, originalIds([3 1 2]));
            testCase.verifyTrue(all(startsWith(originalIds, ...
                ProjectionViewMetadata.GeneratedViewIdPrefix)));
            testCase.verifyEqual(numel(unique(originalIds)), 3);
        end

        function testSuppliedViewAndPassIdsArePreserved(testCase)
            scene = ProjectionViewMetadataTest.makeScene(2);
            scene.layers(1).ViewId = "sensor-view-a";
            scene.layers(2).ViewId = "sensor-view-b";
            scene.layers(1).PassId = "pass-a";
            scene.layers(2).PassId = "pass-b";

            normalized = ProjectionViewMetadata.ensureScene(scene);

            testCase.verifyEqual(ProjectionViewMetadata.ids(normalized), ...
                ["sensor-view-a" "sensor-view-b"]);
            testCase.verifyEqual(string({normalized.layers.PassId}), ...
                ["pass-a" "pass-b"]);
        end

        function testDuplicateAndMalformedViewIdsError(testCase)
            duplicateScene = ProjectionViewMetadataTest.makeScene(2);
            duplicateScene.layers(1).ViewId = "same-view";
            duplicateScene.layers(2).ViewId = "same-view";
            malformedScene = ProjectionViewMetadataTest.makeScene(1);
            malformedScene.layers.ViewId = " leading-space";

            testCase.verifyError( ...
                @() ProjectionViewMetadata.ensureScene(duplicateScene), ...
                "ProjectionViewMetadata:duplicateViewId");
            testCase.verifyError( ...
                @() ProjectionViewMetadata.ensureScene(malformedScene), ...
                "ProjectionViewMetadata:invalidViewId");
        end

        function testUnspecifiedPassDefaultsToOneExplicitGroup(testCase)
            scene = ProjectionViewMetadataTest.makeScene(3);
            normalized = ProjectionViewMetadata.ensureScene(scene);

            testCase.verifyEqual(string({normalized.layers.PassId}), ...
                repmat(ProjectionViewMetadata.DefaultPassId, 1, 3));
        end

        function testPairIdentityIsIndependentOfRoleOrder(testCase)
            forward = ProjectionViewMetadata.pairIdentity("view-b", "view-a");
            reverse = ProjectionViewMetadata.pairIdentity("view-a", "view-b");

            testCase.verifyEqual(forward, reverse);
            testCase.verifyEqual(forward.ViewIds, ["view-a" "view-b"]);
        end

        function testRelativeColumnTimingSupportsBothDirections(testCase)
            layer = ProjectionViewMetadataTest.makeScene(1).layers;
            layer.AcquisitionStartTime = 10;
            layer.LineRateHz = 2;
            layer.ScanAxis = "column";
            layer.ScanDirection = "increasing";
            increasing = ProjectionViewMetadata.sampleLineTimes(layer, [1 3 5]);
            layer.ScanDirection = "decreasing";
            decreasing = ProjectionViewMetadata.sampleLineTimes(layer, [1 3 5]);

            testCase.verifyEqual(increasing, [10 11 12], AbsTol=1e-12);
            testCase.verifyEqual(decreasing, [12 11 10], AbsTol=1e-12);
        end

        function testAbsoluteRowTimingDoesNotRequireUtc(testCase)
            layer = ProjectionViewMetadataTest.makeScene(1).layers;
            startTime = datetime(2026, 7, 11, 9, 30, 0, TimeZone="");
            layer.AcquisitionStartTime = startTime;
            layer.LineRateHz = 4;
            layer.ScanAxis = "row";

            status = ProjectionViewMetadata.timingStatus(layer);
            lineTimes = ProjectionViewMetadata.sampleLineTimes(layer, [1 3]);

            testCase.verifyTrue(status.Available);
            testCase.verifyEqual(status.TimeMode, "absolute");
            testCase.verifyEqual(status.LineCount, 4);
            testCase.verifyEqual(lineTimes, startTime + seconds([0 0.5]));
        end

        function testMissingTimingReportsExplicitCapabilityStatus(testCase)
            layer = ProjectionViewMetadataTest.makeScene(1).layers;

            status = ProjectionViewMetadata.timingStatus(layer);

            testCase.verifyFalse(status.Available);
            testCase.verifyEqual(status.Code, "missingStartAndLineRate");
            testCase.verifyNotEmpty(status.Explanation);
        end

        function testStrictUtcTextParsesWithFixedYearPivot(testCase)
            scene = ProjectionViewMetadataTest.makeScene(3);
            scene.layers(1).AcquisitionStartTime = "311299_235959.25";
            scene.layers(2).AcquisitionStartTime = "01011979_000001";
            scene.layers(3).AcquisitionStartTime = "010179_000001";

            normalized = ProjectionViewMetadata.ensureScene(scene);

            first = normalized.layers(1).AcquisitionStartTime;
            secondTime = normalized.layers(2).AcquisitionStartTime;
            third = normalized.layers(3).AcquisitionStartTime;
            testCase.verifyEqual(string(first.TimeZone), "UTC");
            testCase.verifyEqual(year(first), 1999);
            testCase.verifyEqual(string(secondTime.TimeZone), "UTC");
            testCase.verifyEqual(year(secondTime), 1979);
            testCase.verifyEqual(year(third), 2079);
            testCase.verifyEqual(second(first), 59.25, AbsTol=1e-12);
            testCase.verifyEqual( ...
                normalized.layers(1).AcquisitionStartTimeOriginalText, ...
                "311299_235959.25");
        end

        function testMalformedOrAmbiguousAcquisitionTextErrors(testCase)
            malformed = ProjectionViewMetadataTest.makeScene(1);
            malformed.layers.AcquisitionStartTime = "19991231_235959";
            invalidDate = ProjectionViewMetadataTest.makeScene(1);
            invalidDate.layers.AcquisitionStartTime = "31022026_120000";

            testCase.verifyError( ...
                @() ProjectionViewMetadata.ensureScene(malformed), ...
                "ProjectionViewMetadata:invalidAcquisitionStartTime");
            testCase.verifyError( ...
                @() ProjectionViewMetadata.ensureScene(invalidDate), ...
                "ProjectionViewMetadata:invalidAcquisitionStartTime");
        end

        function testViewMetadataSurvivesMatSerialization(testCase)
            scene = ProjectionViewMetadataTest.makeScene(2);
            scene.layers(1).ViewId = "serialized-a";
            scene.layers(2).ViewId = "serialized-b";
            scene.layers(2).PassId = "second-pass";
            scene = ProjectionViewMetadata.ensureScene(scene);
            filePath = string(tempname) + ".mat";
            testCase.addTeardown(@() delete(filePath));

            save(filePath, "scene");
            loaded = load(filePath, "scene");

            testCase.verifyEqual(ProjectionViewMetadata.ids(loaded.scene), ...
                ["serialized-a" "serialized-b"]);
            testCase.verifyEqual(string(loaded.scene.layers(2).PassId), ...
                "second-pass");
        end

        function testLegacyRealDataLauncherRemainsCompatible(testCase)
            [names, images, definitions, plane] = ...
                ProjectionViewMetadataTest.makeRealDataInputs();

            app = runProjectionViewer(names, images, definitions, plane);
            testCase.addTeardown(@() delete(app));
            drawnow
            state = app.exportState();

            testCase.verifyEqual(state.LayerCount, 2);
            testCase.verifyNumElements(findall(groot, "Type", "figure", ...
                "Name", "Sightline"), 1);
        end

        function testRealDataDefinitionsAcceptOptionalMetadata(testCase)
            [names, images, definitions, plane] = ...
                ProjectionViewMetadataTest.makeRealDataInputs();
            definitions{1}.ViewId = "flight-a-001";
            definitions{2}.ViewId = "flight-a-002";
            definitions{1}.PassId = "flight-a";
            definitions{2}.PassId = "flight-a";
            definitions{1}.AcquisitionStartTime = 0;
            definitions{2}.AcquisitionStartTime = 4;
            definitions{1}.LineRateHz = 10;
            definitions{2}.LineRateHz = 10;
            definitions{2}.ScanDirection = "decreasing";

            scene = ProjectionViewerHarness.createRealDataScene( ...
                names, images, definitions, plane);

            testCase.verifyEqual(ProjectionViewMetadata.ids(scene), ...
                ["flight-a-001" "flight-a-002"]);
            testCase.verifyTrue( ...
                ProjectionViewMetadata.timingStatus(scene.layers(2)).Available);
            testCase.verifyEqual(string(scene.layers(2).ScanDirection), ...
                "decreasing");
        end
    end

    methods (Static, Access = private)
        function scene = makeScene(layerCount)
            images = cell(1, layerCount);
            paths = strings(1, layerCount);
            for layerIndex = 1:layerCount
                images{layerIndex} = uint8(layerIndex * ones(4, 5));
                paths(layerIndex) = "image-" + string(layerIndex) + ".tif";
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=1, ColumnStride=1));
        end

        function [names, images, definitions, plane] = makeRealDataInputs()
            names = ["View A" "View B"];
            images = {uint8(ones(4, 5)), uint8(2 * ones(4, 5))};
            rowPosts = [1 4];
            columnPosts = [1 5];
            baseVectors = zeros(3, 2, 2);
            baseVectors(:, 1, :) = repmat([1; -0.02; 0], 1, 1, 2);
            baseVectors(:, 2, :) = repmat([1; 0.02; 0], 1, 1, 2);
            definitions = cell(1, 2);
            for layerIndex = 1:2
                origins = [zeros(1, 2); ...
                    (layerIndex - 1) * ones(1, 2); [-0.5 0.5]];
                definitions{layerIndex} = struct( ...
                    RowPostIndices=rowPosts, ...
                    ColumnPostIndices=columnPosts, ...
                    ViewVectorOrigins=origins, ...
                    ViewVectors=baseVectors, ...
                    NominalSceneCenter=mean(origins, 2));
            end
            plane = PlanarProjection.definePlaneFromBasis( ...
                [10; 0; 0], [0; 1; 0], [0; 0; 1]);
        end
    end
end

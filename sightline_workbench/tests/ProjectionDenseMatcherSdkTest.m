classdef ProjectionDenseMatcherSdkTest < matlab.unittest.TestCase
    %ProjectionDenseMatcherSdkTest Dense matcher SDK conformance tests.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                projectRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "tests")));
        end
    end

    methods (Test)
        function testRequestValidationNormalizesMappedPair(testCase)
            request = ProjectionDenseMatcherSdkTest.request();

            validated = ProjectionDenseMatchRequest.validate(request);

            testCase.verifyEqual(validated.Format, ...
                ProjectionDenseMatchRequest.Format);
            testCase.verifyEqual(validated.Version, 1);
            testCase.verifyEqual(validated.Roi, [1 8 1 8]);
            testCase.verifyEqual(validated.OverlapMask, true(8));
            testCase.verifyEqual(validated.Seed, 7);
        end

        function testRequestRejectsPresentationDataAndMismatchedMaps(testCase)
            presentation = ProjectionDenseMatcherSdkTest.request();
            presentation.DisplayPyramid = struct();
            mismatched = ProjectionDenseMatcherSdkTest.request();
            mismatched.SourceRows{2} = zeros(7, 8);

            testCase.verifyError(@() ...
                ProjectionDenseMatchRequest.validate(presentation), ...
                "ProjectionDenseMatchRequest:forbiddenPresentationData");
            testCase.verifyError(@() ...
                ProjectionDenseMatchRequest.validate(mismatched), ...
                "ProjectionDenseMatchRequest:invalidArrays");
        end

        function testBaseLifecycleNormalizesProvenanceAndProgress(testCase)
            matcher = ProjectionDenseMatcherFixture();
            probe = ProjectionDenseMatcherTestProbe();

            result = matcher.match(ProjectionDenseMatcherSdkTest.request(), ...
                struct(Count=5), struct(ProgressFcn=@probe.record));

            testCase.verifyEqual(result.Status, "succeeded");
            testCase.verifyNumElements(result.States, 5);
            testCase.verifyTrue(all(result.States == "valid"));
            testCase.verifyEqual(result.Provenance.AlgorithmId, "test.fixture");
            testCase.verifyEqual(result.Provenance.MatcherClass, ...
                "ProjectionDenseMatcherFixture");
            testCase.verifyEqual(result.Provenance.Seed, 7);
            testCase.verifyEqual(result.Execution.Device, "cpu");
            testCase.verifyEqual(probe.Fractions, [0 1]);
            testCase.verifyEqual(probe.Stages, ["starting" "completed"]);
        end

        function testCancellationAndAlgorithmFailureAreClassified(testCase)
            matcher = ProjectionDenseMatcherFixture();
            request = ProjectionDenseMatcherSdkTest.request();

            testCase.verifyError(@() matcher.match(request, struct(), ...
                struct(CancellationFcn=@() true)), ...
                "ProjectionDenseMatcher:cancelled");
            testCase.verifyError(@() matcher.match(request, ...
                struct(ResultMode="error")), ...
                "ProjectionDenseMatcher:algorithmFailure");
        end

        function testResultRejectsSurfaceSubstitution(testCase)
            matcher = ProjectionDenseMatcherFixture();

            testCase.verifyError(@() matcher.match( ...
                ProjectionDenseMatcherSdkTest.request(), ...
                struct(ResultMode="forbidden")), ...
                "ProjectionDenseMatchResult:forbiddenProduct");
        end

        function testResultAcceptsSingletonObservationCovariance(testCase)
            request = ProjectionDenseMatcherSdkTest.request();
            raw = struct(MovingSourceRows=1, MovingSourceColumns=2, ...
                ReferenceSourceRows=1.25, ReferenceSourceColumns=1.5, ...
                States="valid", CovariancePixelsSquared=eye(2));

            result = ProjectionDenseMatchResult.validate(raw, request);

            testCase.verifyEqual(result.CovariancePixelsSquared, eye(2));
            testCase.verifyEqual(result.Score, NaN);
            testCase.verifyEqual(result.Confidence, NaN);
        end

        function testRegistryRequiresExplicitUniqueInstances(testCase)
            matcher = ProjectionDenseMatcherFixture();
            registry = ProjectionDenseMatcherRegistry({matcher});

            resolved = registry.resolve("test.fixture");

            testCase.verifySameHandle(resolved, matcher);
            testCase.verifyEqual(registry.list(), "test.fixture");
            testCase.verifyError(@() registry.register(matcher), ...
                "ProjectionDenseMatcherRegistry:duplicateMatcher");
            testCase.verifyError(@() registry.resolve("not.registered"), ...
                "ProjectionDenseMatcherRegistry:unknownMatcher");
        end

        function testSgmMetadataAndLegacyResultConversion(testCase)
            matcher = ProjectionDenseSgmMatcher();
            request = ProjectionDenseMatcherSdkTest.request();
            legacy = ProjectionDenseMatcherSdkTest.legacyResult();

            result = ProjectionDenseSgmMatcher.resultFromLegacy( ...
                request, legacy);
            metadata = matcher.metadata();

            testCase.verifyEqual(metadata.AlgorithmId, "sightline.sgm");
            testCase.verifyTrue(metadata.CpuSupported);
            testCase.verifyEqual(result.States, ...
                ["valid"; "valid"; "geometrySearchFailure"; ...
                "geometrySearchFailure"]);
            testCase.verifyEqual(result.Diagnostics.ValidCount, 2);
            testCase.verifyEqual(result.Diagnostics.RectifiedMovingImage, ...
                legacy.RectifiedMovingImage);
            testCase.verifyEqual(result.Diagnostics.RectifiedReferenceImage, ...
                legacy.RectifiedReferenceImage);
            testCase.verifyEqual(result.Diagnostics.DisparityMap, ...
                legacy.Disparity);
            testCase.verifyEqual(result.Diagnostics.ValidDisparityMask, ...
                legacy.ValidDisparityMask);
            testCase.verifyEqual(result.Confidence([1 2]), [1; 0.5], ...
                AbsTol=1e-12);
            testCase.verifyFalse(isfield(result, "Surface"));
        end

        function testSgmLegacyBridgeBuildsGraphicsIndependentRequest(testCase)
            [scene, pairWorking, pairMatch] = ...
                ProjectionDenseMatcherSdkTest.legacyInputs();
            pairWorking.LayerImages(1).Image(1) = NaN;
            pairWorking.LayerImages(1).ValidMask(1) = false;
            pairWorking.OverlapMask.Mask(1) = false;

            request = ProjectionDenseSgmMatcher.requestFromLegacy( ...
                scene, pairWorking, pairMatch, ...
                struct(Seed=11, DisparityRange=[0 16]));

            testCase.verifyEqual(request.Seed, 11);
            testCase.verifyEqual(request.ViewIds, ...
                string({scene.layers.ViewId}));
            expectedImage = pairWorking.LayerImages(1).Image;
            expectedImage(~isfinite(expectedImage)) = 0;
            testCase.verifyEqual(request.AnalysisImages{1}, expectedImage);
            testCase.verifyEqual(request.Context.PairMatch, pairMatch);
            testCase.verifyTrue(all(isfinite( ...
                request.AnalysisImages{1}), "all"));
            testCase.verifyTrue(isnan( ...
                request.Context.PairWorking.LayerImages(1).Image(1)));
            testCase.verifyEqual( ...
                request.Context.ExtractorOptions.DisparityRange, [0 16]);
            testCase.verifyFalse(isfield(request, "DisplayPyramid"));
        end
    end

    methods (Static, Access = private)
        function request = request()
            [columns, rows] = meshgrid(1:8, 1:8);
            request = struct(PairId="pair:test", ...
                ViewIds=["view-a" "view-b"], ...
                AnalysisImages={{double(rows), double(columns)}}, ...
                ValidityMasks={{true(8), true(8)}}, ...
                SourceRows={{double(rows), double(rows) + 0.25}}, ...
                SourceColumns={{double(columns), double(columns) - 0.5}}, ...
                CorrectedGeometry=repmat(struct(Type="test"), 1, 2), ...
                Seed=7);
        end

        function legacy = legacyResult()
            surface = struct(ValidMask=logical([1 0; 1 0]), ...
                MovingSourceRows=[1 2; 3 4], ...
                MovingSourceColumns=[5 6; 7 8], ...
                ReferenceSourceRows=[1.1 NaN; 3.1 NaN], ...
                ReferenceSourceColumns=[4.5 NaN; 6.5 NaN], ...
                RaySeparationMeters=[0 Inf; 1 Inf]);
            legacy = struct(Format=ProjectionDenseSurfaceExtractor.Format, ...
                Version=ProjectionDenseSurfaceExtractor.Version, ...
                RectifiedMovingImage=reshape(1:4, 2, 2), ...
                RectifiedReferenceImage=reshape(5:8, 2, 2), ...
                Disparity=single([1 NaN; 2 NaN]), ...
                ValidDisparityMask=logical([1 0; 1 0]), ...
                Surface=surface, Diagnostics=struct(Execution="cpu", ...
                GpuInfo=struct(Requested=false, Enabled=false, Reason=""), ...
                DisparityRangeUsed=[0 16]));
        end


        function [scene, pairWorking, pairMatch] = legacyInputs()
            firstImage = reshape(1:64, 8, 8);
            secondImage = fliplr(firstImage);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {firstImage, secondImage}, ["first.tif" "second.tif"], ...
                struct(RowStride=1, ColumnStride=1));
            [columns, rows] = meshgrid(1:8, 1:8);
            layerIds = string({scene.layers.LayerId});
            first = struct(LayerId=layerIds(1), Image=firstImage, ...
                ValidMask=true(8), SourceRows=double(rows), ...
                SourceColumns=double(columns));
            second = struct(LayerId=layerIds(2), Image=secondImage, ...
                ValidMask=true(8), SourceRows=double(rows), ...
                SourceColumns=double(columns));
            pairWorking = struct(Pair=[1 2], PairLayerIds=layerIds, ...
                LayerImages=[first second], ...
                OverlapMask=struct(Mask=true(8)));
            pairMatch = struct(Count=3, Pair=[1 2]);
        end
    end
end

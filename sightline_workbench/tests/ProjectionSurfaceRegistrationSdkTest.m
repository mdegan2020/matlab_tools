classdef ProjectionSurfaceRegistrationSdkTest < matlab.unittest.TestCase
    %ProjectionSurfaceRegistrationSdkTest S7 lifecycle and built-in tests.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testRequestStrictSchemaForbidsTruthRuntimeAndRigidTerms(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            truthRequest = request;
            truthRequest.Truth = struct();
            callbackRequest = request;
            callbackRequest.ProgressFcn = @(~) [];
            rigidRequest = request;
            rigidRequest.AllowedTransform = "rigid";
            exclusionRequest = request;
            exclusionRequest.PointExclusions = struct( ...
                PointId="unknown", Reason="building");
            frameRequest = request;
            frameRequest.Dem.WorldFrame = "other";

            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationRequest.validate(truthRequest), ...
                "ProjectionSurfaceRegistrationRequest:forbiddenData");
            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationRequest.validate(callbackRequest), ...
                "ProjectionSurfaceRegistrationRequest:forbiddenData");
            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationRequest.validate(rigidRequest), ...
                "ProjectionSurfaceRegistrationRequest:invalidRequest");
            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationRequest.validate(exclusionRequest), ...
                "ProjectionSurfaceRegistrationRequest:invalidExclusions");
            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationRequest.validate(frameRequest), ...
                "ProjectionDemGrid:invalidFrame");
        end

        function testLifecycleReportsProgressCancellationAndFailure(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            probe = ProjectionSurfaceRegistrationProgressProbe();
            result = ProjectionSurfaceRegistrationService.run( ...
                request, ProjectionRobustDemTranslation(), struct(), ...
                struct(ProgressFcn=@(update) probe.record(update)));
            cancelling = struct(CancellationFcn=@() true);

            testCase.verifyEqual(probe.Stages(1), "starting");
            testCase.verifyEqual(probe.Stages(end), "completed");
            testCase.verifyEqual(probe.Fractions([1 end]), [0 1]);
            testCase.verifyGreaterThanOrEqual(result.Timing.TotalSeconds, 0);
            testCase.verifyError(@() ProjectionSurfaceRegistrationService.run( ...
                request, ProjectionRobustDemTranslation(), struct(), cancelling), ...
                "ProjectionSurfaceRegistrationAlgorithm:cancelled");
            testCase.verifyError(@() ProjectionSurfaceRegistrationService.run( ...
                request, ProjectionSurfaceRegistrationTestAlgorithm()), ...
                "ProjectionSurfaceRegistrationAlgorithm:algorithmFailure");
        end

        function testRegistryIsExplicitAndExampleConforms(testCase)
            registry = ProjectionSurfaceRegistrationRegistry({ ...
                ProjectionRobustDemTranslation(), ...
                ProjectionExampleSurfaceRegistration()});
            example = registry.resolve("example.robust-dem-adapter");
            result = example.register( ...
                ProjectionSurfaceRegistrationFixture.cleanRequest());
            correction = ProjectionCorrectionSet.create( ...
                result.CorrectionSetData);

            testCase.verifyEqual(registry.list(), [ ...
                "sightline.registration.robust-dem-translation" ...
                "example.robust-dem-adapter"]);
            testCase.verifyEqual(result.AlgorithmId, ...
                "example.robust-dem-adapter");
            testCase.verifyEqual(correction.Provenance.AlgorithmId, ...
                "example.robust-dem-adapter");
            testCase.verifyEqual(result.Diagnostics.DelegatedAlgorithmId, ...
                "sightline.registration.robust-dem-translation");
            testCase.verifyError(@() registry.resolve("untrusted.ClassName"), ...
                "ProjectionSurfaceRegistrationRegistry:unknownAlgorithm");
        end

        function testRobustTranslationRecoversTruthAndReducesResidual(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            truth = ProjectionSurfaceRegistrationFixture.truth();
            original = horzcat(request.PointSet.Points.PointWorld);
            result = ProjectionSurfaceRegistrationService.run(request);
            errorNorm = norm(result.Transform.TranslationEnuMeters - ...
                truth.TranslationEnuMeters);

            testCase.verifyEqual(result.Status, "succeeded");
            testCase.verifyLessThan(errorNorm, 1e-3);
            testCase.verifyLessThan(result.Residuals.Final.RmsMeters, ...
                result.Residuals.Initial.RmsMeters / 1000);
            testCase.verifyEqual(result.Support.AcceptedPointCount, 20);
            testCase.verifyEqual(result.Support.CoverageFraction, 1);
            testCase.verifyEqual(result.Preview.OriginalPointsWorld, original);
            testCase.verifyFalse(result.Diagnostics.IndividualPointsSnappedToDem);
            testCase.verifyFalse(result.Diagnostics.PointResidualsAreIndependentValidation);
        end

        function testCovarianceAndProposedCorrectionIncludeSharedDemFloor(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            result = ProjectionSurfaceRegistrationService.run(request);
            covariance = result.Covariance.TranslationEnuMetersSquared;
            correction = ProjectionCorrectionSet.create( ...
                result.CorrectionSetData);
            translationBlock = correction.Blocks(string( ...
                {correction.Blocks.Type}) == "globalPositionTranslation");

            testCase.verifyGreaterThanOrEqual(min(eig(covariance)), -1e-12);
            testCase.verifyGreaterThanOrEqual(covariance(1, 1), ...
                request.Dem.Accuracy.HorizontalSigmaMeters ^ 2);
            testCase.verifyGreaterThanOrEqual(covariance(3, 3), ...
                request.Dem.Accuracy.VerticalSigmaMeters ^ 2);
            testCase.verifyTrue(result.Covariance.SharedDemAccuracyIncluded);
            testCase.verifyEqual(correction.Lifecycle, "proposed");
            testCase.verifyEqual(translationBlock.Values, ...
                result.Transform.TranslationWorldMeters.');
            testCase.verifyFalse(correction.Diagnostics.AutoApply);
            testCase.verifyTrue(correction.Diagnostics.RequiresExplicitB8Apply);
            testCase.verifyTrue(all([correction.Passes.TranslationAvailable]));
        end

        function testMasksVoidsAndOutliersRemainExplicitAndStable(testCase)
            request = ProjectionSurfaceRegistrationFixture.maskedOutlierRequest();
            truth = ProjectionSurfaceRegistrationFixture.truth();
            result = ProjectionSurfaceRegistrationService.run(request);
            reasons = string({result.Rejections.Reason});

            testCase.verifyLessThan(norm( ...
                result.Transform.TranslationEnuMeters - ...
                truth.TranslationEnuMeters), 0.2);
            testCase.verifyTrue(any(startsWith(reasons, "pointMask:building")));
            testCase.verifyTrue(any(reasons == ...
                "outsideDemOrVoidOrExcludedCell"));
            testCase.verifyGreaterThan(result.Support.RobustDownweightedCount, 0);
            testCase.verifyTrue(result.Sensitivity.Evaluated);
            testCase.verifyTrue(result.Sensitivity.MaskStable);
            testCase.verifyLessThan(result.Sensitivity.DifferenceNormMeters, ...
                result.Sensitivity.ToleranceMeters);
        end

        function testWeakFlatTerrainReportsGaugeDatumAmbiguity(testCase)
            result = ProjectionSurfaceRegistrationService.run( ...
                ProjectionSurfaceRegistrationFixture.flatRequest());
            correction = ProjectionCorrectionSet.create( ...
                result.CorrectionSetData);

            testCase.verifyEqual(result.Status, "ambiguous");
            testCase.verifyTrue(result.Ambiguity.IsAmbiguous);
            testCase.verifyTrue(result.Ambiguity.GaugeOrDatumConfounding);
            testCase.verifyTrue(any(result.Ambiguity.Reasons == ...
                "weakNormalGeometry"));
            testCase.verifyGreaterThan( ...
                result.Ambiguity.NormalMatrixConditionNumber, 1e8);
            testCase.verifyFalse(result.Diagnostics.AutoApplied);
            testCase.verifyTrue(result.Failure.Valid);
            testCase.verifyTrue(correction.Failure.Valid);
            testCase.verifyTrue(correction.Diagnostics.Ambiguous);
            testCase.verifyEqual(correction.Diagnostics.RegistrationStatus, ...
                "ambiguous");

            degenerate = ProjectionSurfaceRegistrationService.run( ...
                ProjectionSurfaceRegistrationFixture.flatRequest(), ...
                ProjectionRobustDemTranslation(), ...
                struct(RankTolerance=1));
            degenerateCorrection = ProjectionCorrectionSet.create( ...
                degenerate.CorrectionSetData);
            testCase.verifyEqual(degenerate.Status, "degenerate");
            testCase.verifyFalse(degenerate.Failure.Valid);
            testCase.verifyFalse(degenerateCorrection.Failure.Valid);
            testCase.verifyEqual( ...
                degenerateCorrection.Diagnostics.RegistrationStatus, ...
                "degenerate");
        end

        function testMatAndCompactJsonPersistence(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            result = ProjectionSurfaceRegistrationFixture.cleanResult();
            paths = ProjectionSurfaceRegistrationResult.write(result, ...
                fullfile(folder, "registration.mat"), ...
                fullfile(folder, "registration.json"));
            payload = load(paths.MatPath, "registrationResult");
            metadata = jsondecode(fileread(paths.MetadataPath));

            testCase.verifyEqual( ...
                payload.registrationResult.Transform, result.Transform);
            testCase.verifyEqual(string(metadata.AlgorithmId), ...
                result.AlgorithmId);
            testCase.verifyEqual(metadata.PreviewPointCount, 20);
            testCase.verifyFalse(isfield(metadata, "Preview"));
            testCase.verifyFalse(isfield(metadata, "CorrectionSetData"));
            testCase.verifyFalse(metadata.AppliedToSourceGeometry);
        end

        function testRegistrationProductsIntegrateWithoutChangingRawPoints(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            original = horzcat(request.PointSet.Points.PointWorld);
            result = ProjectionSurfaceRegistrationService.run(request);
            products = ProjectionSurfaceProductCatalog.registrationProducts( ...
                request.PointSet, request.Dem, result);
            catalog = ProjectionSurfaceProductCatalog.create( ...
                request.PointSet, {}, products);
            model = ProjectionSurfaceWorkbenchModel(catalog, struct( ...
                OutputProductId="registered", ColorMode="demDifference"));
            registered = model.payload();
            source = ProjectionSurfaceProductCatalog.find( ...
                catalog, "robust-multi-view");

            testCase.verifyTrue(all(ismember(["dem" "registered" ...
                "dem-difference"], model.availableProductIds())));
            testCase.verifyEqual(horzcat(source.Points.PointWorld), original);
            testCase.verifyEqual(registered.PointsWorld, ...
                result.Preview.RegisteredPointsWorld);
            testCase.verifyTrue(registered.ColorAvailable);
            testCase.verifyTrue(registered.CompleteProductRetained);
            testCase.verifyEqual(ProjectionSurfaceProductCatalog.find( ...
                catalog, "dem").Representation, "grid");
        end

        function testDeterminismOptionsAndAutoApplyValidationFailClosed(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            algorithm = ProjectionRobustDemTranslation();
            first = algorithm.register(request);
            second = algorithm.register(request);
            malformed = first;
            malformed.Preview.AppliedToSourceGeometry = true;
            normalized = ProjectionSurfaceRegistrationRequest.validate(request);

            testCase.verifyEqual(first.Transform, second.Transform);
            testCase.verifyEqual(first.Residuals, second.Residuals);
            testCase.verifyError(@() algorithm.register( ...
                request, struct(Unexpected=true)), ...
                "ProjectionRobustDemTranslation:invalidOptions");
            testCase.verifyError(@() ...
                ProjectionSurfaceRegistrationResult.validate( ...
                malformed, normalized, algorithm.metadata()), ...
                "ProjectionSurfaceRegistrationResult:invalidPreview");
        end
    end
end

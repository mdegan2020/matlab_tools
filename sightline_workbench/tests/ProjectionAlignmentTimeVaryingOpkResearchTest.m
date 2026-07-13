classdef ProjectionAlignmentTimeVaryingOpkResearchTest < ...
        matlab.unittest.TestCase
    %ProjectionAlignmentTimeVaryingOpkResearchTest A7 research acceptance.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "tests")));
        end
    end

    methods (Test)
        function testCubicBasisUsesNominalPostsAndPartitionsUnity(testCase)
            columns = [1 17 128 255 384 512];
            [basis, definition] = ProjectionTimeVaryingOpkResearch.basis( ...
                512, columns, 128);

            testCase.verifyEqual(definition.Degree, 3);
            testCase.verifyEqual(definition.PostSpacingPixels, 128);
            testCase.verifyEqual(definition.ControlCount, 7);
            testCase.verifyEqual(sum(basis, 2), ones(numel(columns), 1), ...
                AbsTol=1e-12);
            testCase.verifyLessThanOrEqual(max(sum(basis > 0, 2)), 4);
            testCase.verifyEqual(basis(1, 1), 1);
            testCase.verifyEqual(basis(end, end), 1);
        end

        function testRotationVectorsComposeInTangentSpace(testCase)
            nominal = [cosd(4) -sind(4) 0; ...
                sind(4) cosd(4) 0; 0 0 1];
            vectors = [1e-3 0; -2e-3 0; 0.5e-3 2e-3];
            rotations = ProjectionTimeVaryingOpkResearch.compose( ...
                nominal, vectors);

            testCase.verifyEqual(size(rotations), [3 3 2]);
            testCase.verifyEqual(rotations(:, :, 2) * nominal.', ...
                ProjectionTimeVaryingOpkResearch.compose( ...
                eye(3), vectors(:, 2)), AbsTol=1e-12);
            testCase.verifyEqual(rotations(:, :, 1).' * ...
                rotations(:, :, 1), eye(3), AbsTol=1e-12);
            testCase.verifyError(@() ...
                ProjectionTimeVaryingOpkResearch.compose(eye(2), vectors), ...
                "ProjectionTimeVaryingOpkResearch:invalidRotation");
        end

        function testDenseHeldOutTruthAuditRecoversSpline(testCase)
            report = ProjectionTimeVaryingOpkTruthAudit.run();

            testCase.verifyTrue(report.OperationalTruthSeparated);
            testCase.verifyEqual(report.Dense.Status, ...
                "locallyObservableResearch");
            testCase.verifyTrue(report.Dense.LocallyObservable);
            testCase.verifyEqual( ...
                report.Dense.SelectedPostSpacingPixels, 128);
            testCase.verifyLessThan( ...
                report.Dense.MaximumHeldOutRotationErrorRadians, 1e-10);
            testCase.verifyFalse(report.Dense.AutoApplied);
            testCase.verifyEqual(report.Decision, "retainResearchOnly");
        end

        function testSparseSupportCoarsensAndFailsClosed(testCase)
            report = ProjectionTimeVaryingOpkTruthAudit.run();

            testCase.verifyTrue(report.Sparse.Coarsened);
            testCase.verifyGreaterThan( ...
                report.Sparse.SelectedPostSpacingPixels, 128);
            testCase.verifyEqual(report.Sparse.Status, ...
                "insufficientLocalObservability");
            testCase.verifyFalse(report.Sparse.LocallyObservable);
            testCase.verifyGreaterThan(numel(report.Sparse.History), 1);
            testCase.verifyFalse( ...
                report.Sparse.History(end).SupportSufficient);
        end

        function testPassCommonAndPerViewComponentsAreExplicit(testCase)
            result = ProjectionTimeVaryingOpkResearch.analyze( ...
                ProjectionAlignmentTimeVaryingOpkResearchTest.request());

            testCase.verifyEqual(result.Model.Parameterization, ...
                "localRotationVector");
            testCase.verifyEqual(result.Model.Composition, ...
                "leftComposeExpMapWithNominalRotation");
            testCase.verifyTrue(result.Model.PassCommonComponent);
            testCase.verifyTrue(result.Model.PerImageComponent);
            testCase.verifyEqual(numel(result.Passes), 2);
            testCase.verifyEqual(numel(result.Views), 4);
            testCase.verifySize( ...
                result.Views(1).DifferentialControlRotationVectorsRadians, ...
                [7 3]);
            testCase.verifyFalse(result.ApplicationSupported);
            testCase.verifyEqual(result.Covariance.Status, ...
                "researchLinearized");
        end

        function testPerColumnModeIsAnalysisUpperBoundOnly(testCase)
            request = ProjectionAlignmentTimeVaryingOpkResearchTest. ...
                request(16, 1:16, 2);
            result = ProjectionTimeVaryingOpkResearch.analyze(request, ...
                struct(Mode="perColumnAnalysis"));

            testCase.verifyEqual(result.Status, "analysisUpperBound");
            testCase.verifyTrue(result.Model.PerColumnAnalysisOnly);
            testCase.verifyEqual(result.Model.SelectedPostSpacingPixels, 1);
            testCase.verifyFalse(result.ApplicationSupported);
            testCase.verifyEqual(result.Decision, "retainResearchOnly");
            oversized = ProjectionAlignmentTimeVaryingOpkResearchTest. ...
                request(512, 1:512, 2);
            testCase.verifyError(@() ...
                ProjectionTimeVaryingOpkResearch.analyze(oversized, ...
                struct(Mode="perColumnAnalysis")), ...
                "ProjectionTimeVaryingOpkResearch:resourceLimit");
        end

        function testRequestsMustBePortableTruthFreeAndConsistent(testCase)
            request = ProjectionAlignmentTimeVaryingOpkResearchTest.request();
            embedded = request;
            embedded.Truth = struct(Expected=zeros(1, 3));
            runtime = request;
            runtime.Callback = @sin;
            malformed = request;
            malformed.Views(1).Weights(1) = 0;

            testCase.verifyError(@() ...
                ProjectionTimeVaryingOpkResearch.analyze(embedded), ...
                "ProjectionTimeVaryingOpkResearch:invalidRequest");
            testCase.verifyError(@() ...
                ProjectionTimeVaryingOpkResearch.analyze(runtime), ...
                "ProjectionTimeVaryingOpkResearch:invalidRequest");
            testCase.verifyError(@() ...
                ProjectionTimeVaryingOpkResearch.analyze(malformed), ...
                "ProjectionTimeVaryingOpkResearch:invalidObservations");
        end

        function testResearchCorrectionIsPortableButCannotApply(testCase)
            request = ProjectionAlignmentTimeVaryingOpkResearchTest.request();
            result = ProjectionTimeVaryingOpkResearch.analyze(request);
            scene = ProjectionAlignmentTimeVaryingOpkResearchTest.scene();
            correction = ProjectionTimeVaryingOpkResearch. ...
                toCorrectionSet(scene, result, "a7-parent");
            store = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="a7-parent"));
            before = ProjectionGeometryFingerprint.scene(scene);

            store.propose(correction);
            store.accept(correction.GenerationId);

            testCase.verifyEqual(correction.Lifecycle, "proposed");
            testCase.verifyTrue(correction.Diagnostics.ResearchOnly);
            testCase.verifyFalse( ...
                correction.Diagnostics.ApplicationSupported);
            testCase.verifyEqual(string({correction.Blocks.Type}), ...
                ["passCommonRotationVector" "passCommonRotationVector" ...
                repmat("timeVaryingRotationSpline", 1, 4)]);
            testCase.verifyEqual(unique(string({correction.Blocks.Units})), ...
                "radians");
            testCase.verifyError(@() store.apply(correction.GenerationId), ...
                "ProjectionCorrectionStore:unsupportedApplication");
            testCase.verifyEqual( ...
                ProjectionGeometryFingerprint.scene(store.scene()), before);
            testCase.verifyTrue(store.hasCurrent("accepted"));
            testCase.verifyFalse(store.hasCurrent("applied"));
        end
    end

    methods (Static, Access = private)
        function request = request(width, columns, viewCount)
            if nargin < 1
                width = 512;
            end
            if nargin < 2
                columns = 1:8:width;
            end
            if nargin < 3
                viewCount = 4;
            end
            if viewCount == 4
                passIds = ["pass-a" "pass-a" "pass-b" "pass-b"];
            else
                passIds = repmat("pass-a", 1, viewCount);
            end
            commonTable = [2e-3 -1e-3 0.5e-3; ...
                -1.5e-3 0.8e-3 -0.4e-3];
            template = struct(ViewId="", PassId="", ...
                ImageWidthPixels=0, SourceColumnsPixels=zeros(0, 1), ...
                RotationJacobians=zeros(0, 3), Residuals=zeros(0, 1), ...
                Weights=zeros(0, 1), EvidenceKind="dense");
            views = repmat(template, 1, viewCount);
            for index = 1:viewCount
                passIndex = min(ceil(index / 2), 2);
                effective = repmat(commonTable(passIndex, :), ...
                    numel(columns), 1);
                views(index) = struct(ViewId="view-" + index, ...
                    PassId=passIds(index), ImageWidthPixels=width, ...
                    SourceColumnsPixels=repelem(columns(:), 3), ...
                    RotationJacobians=repmat(eye(3), numel(columns), 1), ...
                    Residuals=reshape(effective.', [], 1), ...
                    Weights=ones(3 * numel(columns), 1), ...
                    EvidenceKind="dense");
            end
            request = struct(SourceGenerationId="a7-test-source", ...
                Views=views);
        end

        function scene = scene()
            images = repmat({uint8(ones(16, 16))}, 1, 4);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["a.tif" "b.tif" "c.tif" "d.tif"], ...
                struct(RowStride=4, ColumnStride=4));
            passes = ["pass-a" "pass-a" "pass-b" "pass-b"];
            for index = 1:4
                scene.layers(index).ViewId = "view-" + index;
                scene.layers(index).PassId = passes(index);
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end
    end
end

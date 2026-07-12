classdef ProjectionCorrectionSetTest < matlab.unittest.TestCase
    %ProjectionCorrectionSetTest Tests immutable correction SDK values.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testOpkAdapterUsesStableIdsRadiansAndExplicitConvention(testCase)
            scene = ProjectionCorrectionSetTest.makeScene();
            result = ProjectionCorrectionSetTest.makeResult(scene);

            set = ProjectionCorrectionOpkAdapter.fromAlignmentResult( ...
                scene, result, ProjectionCorrectionSetTest.fixedOptions());

            testCase.verifyClass(set, "ProjectionCorrectionSet");
            testCase.verifyEqual(set.GenerationId, "generation-001");
            testCase.verifyEqual(string({set.Views.ViewId}), ...
                ["correction-view-1" "correction-view-2"]);
            testCase.verifyEqual(string({set.Views.PassId}), ...
                ["pass-a" "pass-a"]);
            testCase.verifyEqual(set.Convention.Units, "radians");
            testCase.verifyEqual(set.Convention.Order, ...
                ["omega" "phi" "kappa"]);
            testCase.verifyEqual(set.Convention.ActivePassive, "active");
            testCase.verifyEqual(set.Convention.MultiplicationSide, "left");
            testCase.verifyEqual(set.attitudeDegrees("effective"), ...
                reshape([result.SolvedCorrections. ...
                ViewVectorAngularOffsetsDegrees], 3, []).', AbsTol=1e-12);
        end

        function testPropertiesAreImmutableAndViewsAreQueryable(testCase)
            set = ProjectionCorrectionSetTest.makeSet();
            metadata = metaclass(set);
            names = string({metadata.PropertyList.Name});
            generation = metadata.PropertyList(names == "GenerationId");

            testCase.verifyEqual(string(generation.SetAccess), "immutable");
            testCase.verifyEqual(set.view("correction-view-2").PassId, "pass-a");
            testCase.verifyError(@() set.view("missing"), ...
                "ProjectionCorrectionSet:unknownViewId");
        end

        function testRotationLineageComposesExactly(testCase)
            set = ProjectionCorrectionSetTest.makeSet();

            for record = set.Views
                testCase.verifyEqual( ...
                    record.IncrementRotationMatrix * ...
                    record.ParentRotationMatrix, ...
                    record.EffectiveRotationMatrix, AbsTol=1e-12);
            end
            testCase.verifyGreaterThan(norm( ...
                set.Views(1).IncrementRotationVectorRadians), 0);
        end

        function testCompatibilityRejectsStaleGeometryAndPassMismatch(testCase)
            scene = ProjectionCorrectionSetTest.makeScene();
            set = ProjectionCorrectionSetTest.makeSet(scene);
            compatible = set.compatibility(scene);
            stale = scene;
            stale.layers(1).ViewVectorAngularOffsetsDegrees(1) = ...
                stale.layers(1).ViewVectorAngularOffsetsDegrees(1) + 0.01;
            staleStatus = set.compatibility(stale);
            wrongPass = scene;
            wrongPass.layers(1).PassId = "pass-other";
            passStatus = set.compatibility(wrongPass);

            testCase.verifyTrue(compatible.Compatible);
            testCase.verifyFalse(staleStatus.Compatible);
            testCase.verifyEqual(staleStatus.ReasonCode, "staleGeometry");
            testCase.verifyFalse(passStatus.Compatible);
            testCase.verifyEqual(passStatus.ReasonCode, "passMismatch");
            testCase.verifyError(@() set.assertCompatible(stale), ...
                "ProjectionCorrectionSet:staleGeometry");
        end

        function testFingerprintTracksGeometryButNotPresentationOrImage(testCase)
            scene = ProjectionCorrectionSetTest.makeScene();
            baseline = ProjectionGeometryFingerprint.layer(scene.layers(1));
            presentation = scene.layers(1);
            presentation.Visible = ~presentation.Visible;
            presentation.Alpha = 0.2;
            presentation.Image(:) = 0;
            geometry = scene.layers(1);
            geometry.SourceGeometry.ReferenceOrigin(1) = ...
                geometry.SourceGeometry.ReferenceOrigin(1) + 1e-6;

            testCase.verifyEqual( ...
                ProjectionGeometryFingerprint.layer(presentation), baseline);
            testCase.verifyNotEqual( ...
                ProjectionGeometryFingerprint.layer(geometry), baseline);
            testCase.verifyEqual(strlength(baseline), 64);
        end

        function testJsonAndMatRoundTripsPreservePortableValue(testCase)
            set = ProjectionCorrectionSetTest.makeSet();
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            jsonPath = fullfile(folder, "correction.json");
            matPath = fullfile(folder, "correction.mat");

            set.write(jsonPath);
            set.write(matPath);
            fromJson = ProjectionCorrectionSet.read(jsonPath);
            fromMat = ProjectionCorrectionSet.read(matPath);

            testCase.verifyEqual(fromJson.toStruct(), set.toStruct(), ...
                AbsTol=1e-12);
            testCase.verifyEqual(fromMat.toStruct(), set.toStruct());
        end

        function testLegacyAdapterPreservesExistingDegreeContract(testCase)
            set = ProjectionCorrectionSetTest.makeSet();
            legacy = ProjectionCorrectionOpkAdapter. ...
                toLegacySolvedCorrections(set);

            testCase.verifyEqual( ...
                reshape([legacy.ViewVectorAngularOffsetsDegrees], 3, []).', ...
                set.attitudeDegrees("effective"), AbsTol=1e-12);
            testCase.verifyEqual( ...
                reshape([legacy.ProjectionOffsetMeters], 2, []).', ...
                reshape([set.Views.EffectiveProjectionOffsetMeters], 2, []).');
        end

        function testCovarianceDegreeAccessorIsExplicit(testCase)
            original = ProjectionCorrectionSetTest.makeSet();
            data = original.toStruct();
            data.Covariance = struct(Available=true, ...
                AttitudeRadiansSquared=eye(6) * 0.01, ...
                ConditionNumber=12, Reason="available");
            set = ProjectionCorrectionSet.create(data);

            testCase.verifyEqual( ...
                set.attitudeCovarianceDegreesSquared(), ...
                eye(6) * 0.01 * (180 / pi)^2, AbsTol=1e-12);
        end

        function testInvalidDuplicateAndRotationLineageAreRejected(testCase)
            data = ProjectionCorrectionSetTest.makeSet().toStruct();
            duplicate = data;
            duplicate.Views(2).ViewId = duplicate.Views(1).ViewId;
            invalidRotation = data;
            invalidRotation.Views(1).IncrementRotationMatrix = eye(3);
            invalidConvention = data;
            invalidConvention.Convention.Units = "degrees";
            invalidDimension = data;
            invalidDimension.Views(1).EffectiveAttitudeRadians = zeros(1, 4);

            testCase.verifyError( ...
                @() ProjectionCorrectionSet.create(duplicate), ...
                "ProjectionCorrectionSet:duplicateViewId");
            testCase.verifyError( ...
                @() ProjectionCorrectionSet.create(invalidRotation), ...
                "ProjectionCorrectionSet:invalidRotationLineage");
            testCase.verifyError( ...
                @() ProjectionCorrectionSet.create(invalidConvention), ...
                "ProjectionCorrectionSet:invalidConvention");
            testCase.verifyError( ...
                @() ProjectionCorrectionSet.create(invalidDimension), ...
                "ProjectionCorrectionSet:invalidNumericValue");
        end

        function testStrictSchemaRejectsMissingMalformedAndUnsupportedValues(testCase)
            data = ProjectionCorrectionSetTest.makeSet().toStruct();
            missingFormat = rmfield(data, "Format");
            missingVersion = rmfield(data, "Version");
            malformedFormat = data;
            malformedFormat.Format = ["a" "b"];
            unsupportedFormat = data;
            unsupportedFormat.Format = "OtherCorrectionSet";
            malformedVersion = data;
            malformedVersion.Version = 1.5;
            unsupportedVersion = data;
            unsupportedVersion.Version = 2;

            testCase.verifyError(@() ProjectionCorrectionSet.create(missingFormat), ...
                "ProjectionCorrectionSet:missingSchemaField");
            testCase.verifyError(@() ProjectionCorrectionSet.create(missingVersion), ...
                "ProjectionCorrectionSet:missingSchemaField");
            testCase.verifyError(@() ProjectionCorrectionSet.create(malformedFormat), ...
                "ProjectionCorrectionSet:invalidFormat");
            testCase.verifyError(@() ProjectionCorrectionSet.create(unsupportedFormat), ...
                "ProjectionCorrectionSet:unsupportedFormat");
            testCase.verifyError(@() ProjectionCorrectionSet.create(malformedVersion), ...
                "ProjectionCorrectionSet:invalidVersion");
            testCase.verifyError(@() ProjectionCorrectionSet.create(unsupportedVersion), ...
                "ProjectionCorrectionSet:unsupportedVersion");
        end

        function testFunctionBackedGeometryRequiresStableRevisionToken(testCase)
            scene = ProjectionCorrectionSetTest.makeScene();
            set = ProjectionCorrectionSetTest.makeSet(scene);
            unverifiable = scene;
            unverifiable.layers(1).SourceGeometry = rmfield( ...
                unverifiable.layers(1).SourceGeometry, ...
                "GeometryRevisionToken");

            status = set.compatibility(unverifiable);

            testCase.verifyFalse(status.Compatible);
            testCase.verifyEqual(status.ReasonCode, "unverifiableGeometry");
            testCase.verifyError(@() set.assertCompatible(unverifiable), ...
                "ProjectionCorrectionSet:unverifiableGeometry");
            testCase.verifyEqual(strlength( ...
                scene.layers(1).SourceGeometry.GeometryRevisionToken), 64);
        end
    end

    methods (Static, Access = private)
        function set = makeSet(scene)
            if nargin < 1
                scene = ProjectionCorrectionSetTest.makeScene();
            end
            set = ProjectionCorrectionOpkAdapter.fromAlignmentResult( ...
                scene, ProjectionCorrectionSetTest.makeResult(scene), ...
                ProjectionCorrectionSetTest.fixedOptions());
        end

        function options = fixedOptions()
            options = struct(GenerationId="generation-001", ...
                ParentGenerationId="base-generation", ...
                Lifecycle="proposed", ...
                CreatedAt="2026-07-11T12:00:00.000Z");
        end

        function scene = makeScene()
            images = {uint8(ones(8, 9)), uint8(2 * ones(8, 9))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["correction-1.tif" "correction-2.tif"], ...
                struct(RowStride=2, ColumnStride=2));
            scene.layers(1).ViewId = "correction-view-1";
            scene.layers(2).ViewId = "correction-view-2";
            scene.layers(1).PassId = "pass-a";
            scene.layers(2).PassId = "pass-a";
            scene.layers(1).ViewVectorAngularOffsetsDegrees = [1; 2; 3];
            scene.layers(2).ViewVectorAngularOffsetsDegrees = [-1; 0.5; 0];
            scene.layers(1).ProjectionOffsetMeters = [0.2; -0.1];
            scene.layers(2).ProjectionOffsetMeters = [-0.2; 0.1];
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function result = makeResult(scene)
            starting = ProjectionCorrectionSetTest.corrections(scene, false);
            solved = ProjectionCorrectionSetTest.corrections(scene, true);
            layerIds = string({scene.layers.LayerId});
            result = struct(Status="solved", SolvedCorrections=solved, ...
                Convergence=struct(Status="converged", Success=true, ...
                Iterations=3, FunctionEvaluations=9, ExitFlag=1, ...
                Objective=0.1, FirstOrderOptimality=1e-8, Message="ok"), ...
                Diagnostics=struct(StartingCorrections=starting, ...
                BoundsDegrees=[1 1 1], ...
                AttitudeModel=struct(Model="commonPlusDifferential", ...
                LayerIds=layerIds, CommonDeltaDegrees=[0.1 -0.05 0.02], ...
                DifferentialDeltaDegrees=[0.2 0.1 -0.02; ...
                -0.2 -0.1 0.02], PriorPrecision=ones(2, 3)), ...
                Observability=struct(Solution=struct(ConditionNumber=15))));
            result = ProjectionAlignmentResult.validate(result);
        end

        function corrections = corrections(scene, solved)
            corrections = repmat(struct(LayerIndex=0, LayerId="", ...
                ViewVectorAngularOffsetsDegrees=zeros(1, 3), ...
                ProjectionOffsetMeters=zeros(1, 2), SharedScale=1), 1, 2);
            deltas = [0.3 0.05 0; -0.1 -0.15 0.04];
            offsets = [0.05 -0.02; -0.03 0.04];
            for index = 1:2
                layer = scene.layers(index);
                corrections(index).LayerIndex = index;
                corrections(index).LayerId = string(layer.LayerId);
                corrections(index).ViewVectorAngularOffsetsDegrees = ...
                    double(layer.ViewVectorAngularOffsetsDegrees(:).');
                corrections(index).ProjectionOffsetMeters = ...
                    double(layer.ProjectionOffsetMeters(:).');
                if solved
                    corrections(index).ViewVectorAngularOffsetsDegrees = ...
                        corrections(index).ViewVectorAngularOffsetsDegrees + ...
                        deltas(index, :);
                    corrections(index).ProjectionOffsetMeters = ...
                        corrections(index).ProjectionOffsetMeters + ...
                        offsets(index, :);
                end
            end
        end
    end
end

classdef ProjectionViewerStateTest < matlab.unittest.TestCase
    %ProjectionViewerStateTest Tests for viewer state serialization.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testValidateNormalizesViewerState(testCase)
            state = ProjectionViewerStateTest.makeState();

            result = ProjectionViewerState.validate(state, 2);

            testCase.verifyEqual(string(result.Format), ProjectionViewerState.Format);
            testCase.verifyEqual(result.Version, ProjectionViewerState.Version);
            testCase.verifyEqual(result.LayerCount, 2);
            testCase.verifyEqual(result.SelectedLayerIndex, 2);
            testCase.verifyEqual(result.Projection.TipDegrees, 4.5, ...
                AbsTol=ProjectionViewerStateTest.Tol);
            testCase.verifyEqual(result.View.TwistDegrees, -2, ...
                AbsTol=ProjectionViewerStateTest.Tol);
            testCase.verifyEqual(result.Layers(2).ProjectionOffsetMeters, ...
                [1.5 -2.5], AbsTol=ProjectionViewerStateTest.Tol);
            testCase.verifyEqual(result.Layers(2).ViewVectorAngularOffsetsDegrees, ...
                [0.1 0.2 -0.3], AbsTol=ProjectionViewerStateTest.Tol);
        end

        function testEncodeDecodeRoundTripIsPrettyJson(testCase)
            state = ProjectionViewerStateTest.makeState();

            jsonText = ProjectionViewerState.encode(state);
            result = ProjectionViewerState.decode(jsonText, 2);

            testCase.verifyTrue(contains(jsonText, newline));
            testCase.verifyTrue(contains(jsonText, '"ProjectionOffsetMeters"'));
            testCase.verifyEqual(result.Layers(1).BlendMode, "alpha");
            testCase.verifyEqual(result.Layers(2).BlendMode, "redBlueAnaglyph");
        end

        function testWriteReadRoundTrip(testCase)
            state = ProjectionViewerStateTest.makeState();
            filePath = fullfile(tempdir, "projection_viewer_state_test.json");
            testCase.addTeardown(@() delete(filePath));

            ProjectionViewerState.write(filePath, state);
            result = ProjectionViewerState.read(filePath, 2);

            testCase.verifyTrue(isfile(filePath));
            testCase.verifyEqual(result.Camera.ViewAngle, state.Camera.ViewAngle, ...
                AbsTol=ProjectionViewerStateTest.Tol);
            testCase.verifyEqual(result.Layers(2).Alpha, state.Layers(2).Alpha, ...
                AbsTol=ProjectionViewerStateTest.Tol);
        end

        function testLayerCountMismatchErrors(testCase)
            state = ProjectionViewerStateTest.makeState();

            testCase.verifyError( ...
                @() ProjectionViewerState.validate(state, 1), ...
                "ProjectionViewerState:layerCountMismatch");
        end

        function testInvalidAlphaErrors(testCase)
            state = ProjectionViewerStateTest.makeState();
            state.Layers(1).Alpha = 1.5;

            testCase.verifyError( ...
                @() ProjectionViewerState.validate(state, 2), ...
                "ProjectionViewerState:invalidAlpha");
        end
    end

    methods (Static, Access = private)
        function state = makeState()
            state = struct();
            state.Format = "ProjectionViewerState";
            state.Version = 1;
            state.LayerCount = 2;
            state.SelectedLayerIndex = 2;
            state.Projection = struct(TipDegrees=4.5, TiltDegrees=-3.25);
            state.View = struct(TwistDegrees=-2);
            state.Camera = struct();
            state.Camera.Position = [10 20 30];
            state.Camera.Target = [1 2 3];
            state.Camera.UpVector = [0 1 0];
            state.Camera.ViewAngle = 8.5;
            state.Camera.Projection = "orthographic";
            state.Layers = [ ...
                ProjectionViewerStateTest.makeLayerState(1, "layer1", "alpha", ...
                1, true, [0 0], [0 0 0]), ...
                ProjectionViewerStateTest.makeLayerState(2, "layer2", ...
                "redBlueAnaglyph", 0.4, false, [1.5 -2.5], [0.1 0.2 -0.3])];
        end

        function layer = makeLayerState(index, name, blendMode, alpha, visible, ...
                projectionOffsetMeters, viewVectorAngularOffsetsDegrees)
            layer = struct();
            layer.Index = index;
            layer.Name = name;
            layer.ImagePath = name + ".tif";
            layer.Alpha = alpha;
            layer.Visible = visible;
            layer.BlendMode = blendMode;
            layer.ProjectionOffsetMeters = projectionOffsetMeters;
            layer.ViewVectorAngularOffsetsDegrees = viewVectorAngularOffsetsDegrees;
        end
    end
end

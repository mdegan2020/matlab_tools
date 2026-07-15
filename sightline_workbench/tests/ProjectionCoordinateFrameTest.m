classdef ProjectionCoordinateFrameTest < matlab.unittest.TestCase
    %ProjectionCoordinateFrameTest Explicit world/display frame contracts.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testEcefEnuRoundTripAndCovarianceRotation(testCase)
            origin = ProjectionCoordinateFrameTest.ecef(42, -71, 120);
            frame = ProjectionCoordinateFrame.ecef( ...
                "WGS84-ECEF", origin);
            local = [0 10 -4; 0 -6 2; 0 3 8];
            world = origin + frame.WorldToLocalRotation.' * local;
            covarianceWorld = diag([9 4 1]);

            displayed = ProjectionCoordinateFrame.worldToDisplay( ...
                frame, world, "localENU");
            recovered = ProjectionCoordinateFrame.displayToWorld( ...
                frame, displayed, "localENU");
            covarianceDisplay = ProjectionCoordinateFrame. ...
                covarianceToDisplay(frame, covarianceWorld, "localENU");

            testCase.verifyEqual(displayed, local, AbsTol=1e-8);
            testCase.verifyEqual(recovered, world, AbsTol=1e-8);
            testCase.verifyEqual(covarianceDisplay, ...
                frame.WorldToLocalRotation * covarianceWorld * ...
                frame.WorldToLocalRotation.', AbsTol=1e-12);
            testCase.verifyEqual(frame.AxisNames, ["East" "North" "Up"]);
            testCase.verifyTrue(frame.AbsoluteHeightAvailable);
            testCase.verifyTrue(frame.Reversible);
        end

        function testHaeComesFromEllipsoidNotLocalUpOrWorldZ(testCase)
            origin = ProjectionCoordinateFrameTest.ecef(42, -71, 120);
            frame = ProjectionCoordinateFrame.ecef("ecef", origin);
            points = [ProjectionCoordinateFrameTest.ecef(42, -71, 135) ...
                ProjectionCoordinateFrameTest.ecef(42.001, -70.999, 87)];

            heights = ProjectionCoordinateFrame.haeHeight(frame, points);
            local = ProjectionCoordinateFrame.worldToDisplay( ...
                frame, points, "localENU");

            testCase.verifyEqual(heights, [135 87], AbsTol=1e-6);
            testCase.verifyGreaterThan(abs(local(3, 2) - heights(2)), 1);
            testCase.verifyNotEqual(points(3, 1), heights(1));
        end

        function testUnknownFrameNeverGuessesLocalOrAbsoluteHeight(testCase)
            frame = ProjectionCoordinateFrame.fromDeclaration( ...
                "synthetic-world", [10; 20; 30]);
            world = [11; 22; 33];

            relative = ProjectionCoordinateFrame.worldToDisplay( ...
                frame, world, "originRelativeWorld");

            testCase.verifyEqual(frame.CoordinateKind, "unknown");
            testCase.verifyFalse(frame.AbsoluteHeightAvailable);
            testCase.verifyEqual(relative, [1; 2; 3]);
            testCase.verifyError(@() ProjectionCoordinateFrame. ...
                worldToDisplay(frame, world, "localENU"), ...
                "ProjectionCoordinateFrame:unsupportedDisplayFrame");
            testCase.verifyError(@() ProjectionCoordinateFrame. ...
                haeHeight(frame, world), ...
                "ProjectionCoordinateFrame:absoluteHeightUnavailable");
        end

        function testOnlyRecognizedDeclarationsBecomeEcef(testCase)
            origin = ProjectionCoordinateFrameTest.ecef(0, 0, 0);
            recognized = ProjectionCoordinateFrame.fromDeclaration( ...
                "EPSG:4978", origin);
            unrecognized = ProjectionCoordinateFrame.fromDeclaration( ...
                "large-number-frame", origin);

            testCase.verifyEqual(recognized.CoordinateKind, "ecef");
            testCase.verifyEqual(unrecognized.CoordinateKind, "unknown");
        end

        function testImproperRotationIsRejected(testCase)
            frame = ProjectionCoordinateFrame.localCartesian( ...
                "local", zeros(3, 1), eye(3));
            frame.WorldToLocalRotation(3, 3) = -1;

            testCase.verifyError(@() ProjectionCoordinateFrame.validate(frame), ...
                "ProjectionCoordinateFrame:invalidRotation");
        end
    end

    methods (Static, Access = private)
        function value = ecef(latitude, longitude, hae)
            ellipsoid = wgs84Ellipsoid("meter");
            [x, y, z] = geodetic2ecef( ...
                ellipsoid, latitude, longitude, hae);
            value = [x; y; z];
        end
    end
end

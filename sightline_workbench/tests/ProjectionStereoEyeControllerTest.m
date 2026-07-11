classdef ProjectionStereoEyeControllerTest < matlab.unittest.TestCase
    %ProjectionStereoEyeControllerTest Tests runtime stereo-eye assignment.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testPhysicalOrderingKeepsRedOnLeft(testCase)
            controller = ProjectionStereoEyeController();
            pairId = ProjectionViewMetadata.pairIdentity( ...
                "view-a", "view-b").PairId;

            assignment = controller.resolve(pairId, ...
                ["view-b" "view-a"], [2 -3; 0 0; 0 0], [1; 0; 0]);

            testCase.verifyEqual(assignment.LeftViewId, "view-a");
            testCase.verifyEqual(assignment.RedViewId, "view-a");
            testCase.verifyEqual(assignment.RightViewId, "view-b");
        end

        function testRoleOrderDoesNotChangeEyes(testCase)
            controller = ProjectionStereoEyeController();
            pairId = ProjectionViewMetadata.pairIdentity( ...
                "view-a", "view-b").PairId;
            first = controller.resolve(pairId, ["view-a" "view-b"], ...
                [-2 2; 0 0; 0 0], [1; 0; 0]);

            swappedRoles = controller.resolve(pairId, ...
                ["view-b" "view-a"], [2 -2; 0 0; 0 0], [1; 0; 0]);

            testCase.verifyEqual(swappedRoles.LeftViewId, first.LeftViewId);
            testCase.verifyEqual(swappedRoles.RightViewId, first.RightViewId);
        end

        function testHysteresisRetainsThenSwitches(testCase)
            controller = ProjectionStereoEyeController();
            pairId = ProjectionViewMetadata.pairIdentity( ...
                "view-a", "view-b").PairId;
            controller.resolve(pairId, ["view-a" "view-b"], ...
                [-1 1; 0 0; 0 0], [1; 0; 0]);

            retained = controller.resolve(pairId, ["view-a" "view-b"], ...
                [0.01 -0.01; 0 10; 0 0], [1; 0; 0]);
            switched = controller.resolve(pairId, ["view-a" "view-b"], ...
                [1 -1; 0 0; 0 0], [1; 0; 0]);

            testCase.verifyEqual(retained.LeftViewId, "view-a");
            testCase.verifyEqual(retained.Status, "retainedHysteresis");
            testCase.verifyTrue(retained.IsDegenerate);
            testCase.verifyEqual(switched.LeftViewId, "view-b");
            testCase.verifyEqual(switched.Status, "automaticSwitched");
        end

        function testManualSwapAndResetArePairStable(testCase)
            controller = ProjectionStereoEyeController();
            pairId = ProjectionViewMetadata.pairIdentity( ...
                "view-a", "view-b").PairId;
            viewIds = ["view-a" "view-b"];
            origins = [-1 1; 0 0; 0 0];
            rightVector = [1; 0; 0];
            automatic = controller.resolve( ...
                pairId, viewIds, origins, rightVector);

            manual = controller.swapManual( ...
                pairId, viewIds, origins, rightVector);
            reset = controller.resetManual( ...
                pairId, viewIds, origins, rightVector);

            testCase.verifyEqual(manual.LeftViewId, automatic.RightViewId);
            testCase.verifyTrue(manual.ManualOverride);
            testCase.verifyEqual(manual.Status, "manualOverride");
            testCase.verifyEqual(reset.LeftViewId, automatic.LeftViewId);
            testCase.verifyFalse(reset.ManualOverride);
        end

        function testDegenerateFirstViewUsesStableIdentityFallback(testCase)
            controller = ProjectionStereoEyeController();
            pairId = ProjectionViewMetadata.pairIdentity( ...
                "view-b", "view-a").PairId;

            assignment = controller.resolve(pairId, ...
                ["view-b" "view-a"], [0 0; -1 1; 0 0], [1; 0; 0]);

            testCase.verifyEqual(assignment.LeftViewId, "view-a");
            testCase.verifyEqual(assignment.Status, "degenerateNoHistory");
            testCase.verifyTrue(assignment.IsDegenerate);
        end
    end
end

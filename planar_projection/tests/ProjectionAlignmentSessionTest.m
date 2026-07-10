classdef ProjectionAlignmentSessionTest < matlab.unittest.TestCase
    %ProjectionAlignmentSessionTest Tests staged graphics-free session state.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testFreshSessionMarksEveryComputedStageStale(testCase)
            session = ProjectionAlignmentSession();

            state = session.diagnostics();

            testCase.verifyEqual(state.Stage, "setup");
            testCase.verifyEqual(state.Revision, 0);
            testCase.verifyTrue(all([state.Stale.Match, state.Stale.Filter, ...
                state.Stale.Solve, state.Stale.Preview, state.Stale.Apply]));
        end

        function testCurationInvalidatesSolveWithoutInvalidatingMatch(testCase)
            session = ProjectionAlignmentSession();
            session.storeMatches(struct(Id="request"), struct(Id="working"), ...
                struct(Id="raw"), struct(Id="preRoi"), ...
                struct(Id="filtered"), {true(4, 1)}, {false(4, 1)});
            matchedState = session.diagnostics();
            session.storeSolve(struct(Status="solved"));

            session.CuratedMatchMask = {[true; true; false; true]};
            session.DeletedMatchMask = {[false; false; true; false]};
            session.invalidateSolve();
            curatedState = session.diagnostics();

            testCase.verifyEqual(curatedState.Stage, "curated");
            testCase.verifyFalse(curatedState.Stale.Match);
            testCase.verifyFalse(curatedState.Stale.Filter);
            testCase.verifyTrue(curatedState.Stale.Solve);
            testCase.verifyEqual(curatedState.MatchRevision, ...
                matchedState.MatchRevision);
            testCase.verifyEqual(session.RawMatchResult.Id, "raw");
            testCase.verifyEmpty(fieldnames(session.Result));
        end

        function testPreviewApplyAndRevertTransitionsAreExplicit(testCase)
            session = ProjectionAlignmentSession();
            session.storeMatches(struct(Id="request"), struct(Id="working"), ...
                struct(Id="raw"), struct(Id="preRoi"), ...
                struct(Id="filtered"), {true(3, 1)}, {false(3, 1)});
            session.storeSolve(struct(Status="solved"));

            solvedState = session.diagnostics();
            session.markPreviewed();
            previewState = session.diagnostics();
            session.markApplied();
            appliedState = session.diagnostics();
            session.markReverted();
            revertedState = session.diagnostics();

            testCase.verifyFalse(solvedState.Stale.Solve);
            testCase.verifyTrue(solvedState.Stale.Preview);
            testCase.verifyEqual(previewState.Stage, "previewed");
            testCase.verifyFalse(previewState.Stale.Preview);
            testCase.verifyEqual(appliedState.Stage, "applied");
            testCase.verifyFalse(appliedState.Stale.Apply);
            testCase.verifyEqual(revertedState.Stage, "solved");
            testCase.verifyTrue(revertedState.Stale.Preview);
            testCase.verifyTrue(revertedState.Stale.Apply);
        end

        function testComputationResetKeepsRoiAndRuntimeCache(testCase)
            session = ProjectionAlignmentSession();
            session.RoiBounds = [1 2 3 4];
            session.WorkingImageCacheKey = struct(Id="key");
            session.WorkingImageCacheValue = struct(Id="value");
            session.WorkingImageCacheHits = 2;
            session.storeMatches(struct(Id="request"), struct(Id="working"), ...
                struct(Id="raw"), struct(Id="preRoi"), ...
                struct(Id="filtered"), {true(3, 1)}, {false(3, 1)});

            session.clearComputation();

            testCase.verifyEqual(session.RoiBounds, [1 2 3 4]);
            testCase.verifyEqual(session.WorkingImageCacheKey.Id, "key");
            testCase.verifyEqual(session.WorkingImageCacheValue.Id, "value");
            testCase.verifyEqual(session.WorkingImageCacheHits, 2);
            testCase.verifyEqual(session.Stage, "setup");
        end
    end
end

classdef ProjectionSurfaceRunTest < matlab.unittest.TestCase
    %ProjectionSurfaceRunTest Defensive MAT saved-run ingestion tests.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "tests")));
        end
    end

    methods (Test)
        function testCurrentCatalogAndRunLoadHeadlessly(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            catalogPath = ProjectionSurfaceRunTest.path(testCase);
            save(catalogPath, "catalog", "-v7");
            catalogLoaded = ProjectionSurfaceRun.read(catalogPath);
            surfaceWorkbenchRun = struct( ...
                Format=ProjectionSurfaceWorkbenchRunner.Format, ...
                Version=ProjectionSurfaceWorkbenchRunner.Version, ...
                Status="succeeded", Message="complete", ...
                Catalog=catalog, PointSet=struct(), ...
                GraphicsStateIncluded=false);
            runPath = ProjectionSurfaceRunTest.path(testCase);
            save(runPath, "surfaceWorkbenchRun", "-v7");
            runLoaded = ProjectionSurfaceRun.read(runPath);

            testCase.verifyEqual(catalogLoaded.SourceVariable, "catalog");
            testCase.verifyEqual(runLoaded.SourceVariable, ...
                "surfaceWorkbenchRun");
            testCase.verifyEqual(runLoaded.Catalog.GenerationId, ...
                catalog.GenerationId);
            testCase.verifyEqual(runLoaded.CoordinateFrame, ...
                catalog.CoordinateFrame);
            testCase.verifyFalse(runLoaded.GraphicsStateIncluded);
            testCase.verifyFalse(ProjectionSurfaceWorkbenchFixture. ...
                hasRuntimeHandle(runLoaded));
        end

        function testPointSetLoadsWithExplicitLegacyDecision(testCase)
            pointSet = ProjectionSurfaceWorkbenchFixture.request().PointSet;
            path = ProjectionSurfaceRunTest.path(testCase);
            save(path, "pointSet", "-v7");

            testCase.verifyError(@() ProjectionSurfaceRun.read(path), ...
                "ProjectionSurfaceRun:legacyFrameDecisionRequired");

            loaded = ProjectionSurfaceRun.read(path, ...
                struct(LegacyFrameDecision="unknown"));

            testCase.verifyEqual(loaded.SourceVariable, "pointSet");
            testCase.verifyEqual(loaded.CoordinateFrame.CoordinateKind, ...
                "unknown");
            testCase.verifyGreaterThan( ...
                loaded.Catalog.Diagnostics.AvailableProductCount, 0);
        end

        function testVersionOneCatalogRequiresDecisionOrOverride(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            catalog.Version = 1;
            catalog = rmfield(catalog, "CoordinateFrame");
            path = ProjectionSurfaceRunTest.path(testCase);
            save(path, "catalog", "-v7");

            testCase.verifyError(@() ProjectionSurfaceRun.read(path), ...
                "ProjectionSurfaceRun:legacyFrameDecisionRequired");

            unknown = ProjectionSurfaceRun.read(path, ...
                struct(LegacyFrameDecision="unknown"));
            override = ProjectionCoordinateFrame.localCartesian( ...
                catalog.WorldFrame, zeros(3, 1), eye(3), ...
                "operatorLegacyOverride");
            overridden = ProjectionSurfaceRun.read(path, ...
                struct(CoordinateFrameOverride=override));

            testCase.verifyEqual(unknown.Catalog.Version, ...
                ProjectionSurfaceProductCatalog.Version);
            testCase.verifyEqual(unknown.CoordinateFrame.CoordinateKind, ...
                "unknown");
            testCase.verifyEqual(overridden.CoordinateFrame.CoordinateKind, ...
                "localCartesian");
            testCase.verifyEqual(overridden.CoordinateFrame.Derivation, ...
                "operatorLegacyOverride");
        end

        function testRuntimeRejectedAndCompatibleFutureRunWrapperLoads(testCase)
            catalog = struct(Callback=@() true);
            runtimePath = ProjectionSurfaceRunTest.path(testCase);
            save(runtimePath, "catalog", "-v7");
            testCase.verifyError(@() ProjectionSurfaceRun.read(runtimePath), ...
                "ProjectionSurfaceRun:runtimeState");

            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            surfaceWorkbenchRun = struct( ...
                Format=ProjectionSurfaceWorkbenchRunner.Format, Version=3, ...
                Status="succeeded", Catalog=catalog, ...
                GraphicsStateIncluded=false);
            futurePath = ProjectionSurfaceRunTest.path(testCase);
            save(futurePath, "surfaceWorkbenchRun", "-v7");

            future = ProjectionSurfaceRun.read(futurePath);

            testCase.verifyEqual(future.Run.Version, 3);
            testCase.verifyEqual(future.Catalog.Version, ...
                ProjectionSurfaceProductCatalog.Version);

            catalog.Version = 99;
            invalidCatalogPath = ProjectionSurfaceRunTest.path(testCase);
            save(invalidCatalogPath, "catalog", "-v7");

            testCase.verifyError(@() ...
                ProjectionSurfaceRun.read(invalidCatalogPath), ...
                "ProjectionSurfaceProductCatalog:unsupportedSchema");
        end

        function testUnsupportedVariablesAndFrameMismatchAreRejected(testCase)
            unrelated = struct(Value=1);
            unsupportedPath = ProjectionSurfaceRunTest.path(testCase);
            save(unsupportedPath, "unrelated", "-v7");
            testCase.verifyError(@() ...
                ProjectionSurfaceRun.read(unsupportedPath), ...
                "ProjectionSurfaceRun:unsupportedContents");

            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            path = ProjectionSurfaceRunTest.path(testCase);
            save(path, "catalog", "-v7");
            override = ProjectionCoordinateFrame.localCartesian( ...
                "different-world", zeros(3, 1));
            testCase.verifyError(@() ProjectionSurfaceRun.read(path, ...
                struct(CoordinateFrameOverride=override)), ...
                "ProjectionSurfaceRun:frameMismatch");
        end
    end

    methods (Static, Access = private)
        function path = path(testCase)
            path = string(tempname) + ".mat";
            testCase.addTeardown(@() ProjectionSurfaceRunTest.deleteIfPresent(path));
        end

        function deleteIfPresent(path)
            if isfile(path)
                delete(path);
            end
        end
    end
end

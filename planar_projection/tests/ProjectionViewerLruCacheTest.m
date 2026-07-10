classdef ProjectionViewerLruCacheTest < matlab.unittest.TestCase
    %ProjectionViewerLruCacheTest Tests byte-bounded runtime cache behavior.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testLeastRecentlyUsedEntryIsEvicted(testCase)
            cache = ProjectionViewerLruCache(10);
            cache.put("a", struct(Value=1), 4);
            cache.put("b", struct(Value=2), 4);
            cache.get("a");

            cache.put("c", struct(Value=3), 4);
            [foundA, valueA] = cache.get("a");
            [foundB, ~] = cache.get("b");
            [foundC, valueC] = cache.get("c");
            diagnostics = cache.diagnostics();

            testCase.verifyTrue(foundA);
            testCase.verifyFalse(foundB);
            testCase.verifyTrue(foundC);
            testCase.verifyEqual(valueA.Value, 1);
            testCase.verifyEqual(valueC.Value, 3);
            testCase.verifyEqual(diagnostics.EntryCount, 2);
            testCase.verifyEqual(diagnostics.TotalBytes, 8);
            testCase.verifyEqual(diagnostics.EvictionCount, 1);
        end

        function testOversizedEntryIsNotStored(testCase)
            cache = ProjectionViewerLruCache(5);

            stored = cache.put("large", struct(Value=1), 6);
            [found, ~] = cache.get("large");
            diagnostics = cache.diagnostics();

            testCase.verifyFalse(stored);
            testCase.verifyFalse(found);
            testCase.verifyEqual(diagnostics.TotalBytes, 0);
        end

        function testClearResetsEntriesAndEvictions(testCase)
            cache = ProjectionViewerLruCache(5);
            cache.put("a", struct(Value=1), 4);
            cache.put("b", struct(Value=2), 4);

            cache.clear();
            diagnostics = cache.diagnostics();

            testCase.verifyEqual(diagnostics.EntryCount, 0);
            testCase.verifyEqual(diagnostics.TotalBytes, 0);
            testCase.verifyEqual(diagnostics.EvictionCount, 0);
        end
    end
end

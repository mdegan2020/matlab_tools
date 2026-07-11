classdef ProjectionBackendRadiometryTest < matlab.unittest.TestCase
    %ProjectionBackendRadiometryTest Tests explicit output value encoding.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testUint8IdentityPolicyPreservesIntegerValues(testCase)
            values = uint8(reshape(0:15, 4, 4));
            output = ProjectionBackendRadiometryTest.outputPolicy( ...
                OutputClass="uint8", RadiometricScale=255);

            encoded = ProjectionBackendRadiometry.prepare(values, output);

            testCase.verifyEqual(encoded, values);
        end

        function testScaleOffsetAndFillAreDeterministic(testCase)
            values = [-2 0 2 NaN];
            output = ProjectionBackendRadiometryTest.outputPolicy( ...
                OutputClass="uint16", RadiometricScale=4, ...
                RadiometricOffset=-2, FillValue=0);

            encoded = ProjectionBackendRadiometry.prepare(values, output);
            metadata = ProjectionBackendRadiometry.metadata(output);

            expected = uint16(round([0 0.5 1 0.5] * double(intmax("uint16"))));
            testCase.verifyEqual(encoded, expected);
            testCase.verifyEqual(metadata.Scale, 4);
            testCase.verifyEqual(metadata.Offset, -2);
            testCase.verifyEqual(metadata.StoredNormalizationDivisor, ...
                double(intmax("uint16")));
        end

        function testErrorPolicyRejectsOutOfRangeValues(testCase)
            output = ProjectionBackendRadiometryTest.outputPolicy( ...
                OutOfRangePolicy="error");

            testCase.verifyError(@() ...
                ProjectionBackendRadiometry.prepare([0 2], output), ...
                "ProjectionBackendRadiometry:outOfRange");
        end
    end

    methods (Static, Access = private)
        function output = outputPolicy(overrides)
            arguments
                overrides.OutputClass = "uint8"
                overrides.RadiometricScale = 1
                overrides.RadiometricOffset = 0
                overrides.FillValue = 0
                overrides.OutOfRangePolicy = "clip"
            end
            output = struct(OutputClass=string(overrides.OutputClass), ...
                RadiometricScale=double(overrides.RadiometricScale), ...
                RadiometricOffset=double(overrides.RadiometricOffset), ...
                FillValue=double(overrides.FillValue), ...
                OutOfRangePolicy=string(overrides.OutOfRangePolicy));
        end
    end
end

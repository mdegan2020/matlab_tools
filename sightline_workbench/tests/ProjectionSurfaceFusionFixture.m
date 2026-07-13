classdef ProjectionSurfaceFusionFixture
    %ProjectionSurfaceFusionFixture Public-contract fixtures for fusion tests.

    methods (Static)
        function request = request()
            coordinates = [ ...
                -1.00 -0.05 0.95 -1.00 0.05 1.00 -0.10 0.15; ...
                -0.95 -1.00 -0.90 0.05 0.00 0.10 0.00 0.05; ...
                10.10 9.90 10.05 9.95 10.05 10.00 12.00 12.10];
            modes = [repmat("roof", 1, 6) repmat("parapet", 1, 2)];
            request = struct(PointSet= ...
                ProjectionSurfaceFusionFixture.pointSet(coordinates, modes), ...
                RoiWorld=[-2 2; -2 2; 8 13], GsdMeters=0.5, ...
                VoxelScaleMultipliers=[0.5 1 2], Seed=19);
        end

        function request = duplicatePairCountRequest()
            request = ProjectionSurfaceFusionFixture.request();
            for index = 1:numel(request.PointSet.Points)
                request.PointSet.Points(index).PairRecordCount = ...
                    request.PointSet.Points(index).PairRecordCount + 100;
            end
        end

        function pointSet = pointSet(coordinates, modes)
            pointSet = ProjectionSurfaceFusionFixture.basePointSet();
            template = pointSet.Points;
            points = repmat(template, 1, size(coordinates, 2));
            normalizedModes = ProjectionSurfaceFusionFixture. ...
                normalizeModes(modes);
            competing = numel(unique(normalizedModes)) > 1;
            for index = 1:numel(points)
                points(index).PointId = "surface-input-" + index;
                points(index).PointWorld = coordinates(:, index);
                points(index).ModeId = string(modes(index));
                points(index).CompetingMode = competing;
                points(index).CovarianceWorldMetersSquared = ...
                    diag([0.04 0.04 0.09]);
                points(index).PrincipalAxisSigmasMeters = [0.2 0.2 0.3];
                points(index).PairRecordCount = index + 2;
            end
            pointSet.Points = points;
            pointSet.GenerationId = "surface-set-" + extractBefore( ...
                ProjectionGeometryFingerprint.hash(struct( ...
                Coordinates=coordinates, Modes=modes)), 17);
        end

        function total = totalEvidence(scaleResult)
            total = 0;
            for mode = scaleResult.Modes
                total = total + sum(double(mode.EvidenceWeights));
            end
        end

        function classes = evidenceClasses(scaleResult)
            classes = strings(1, numel(scaleResult.Modes));
            for index = 1:numel(scaleResult.Modes)
                classes(index) = class(scaleResult.Modes(index).EvidenceWeights);
            end
        end

        function coordinates = fusedCoordinates(result)
            if isempty(result.FusedPoints)
                coordinates = zeros(3, 0);
            else
                coordinates = horzcat(result.FusedPoints.PointWorld);
            end
        end

        function labels = fusedModes(result)
            labels = sort(string({result.FusedPoints.ModeId}));
        end
    end

    methods (Static, Access = private)
        function pointSet = basePointSet()
            point = [0; 0; 10];
            first = ProjectionSurfaceFusionFixture.record( ...
                "record-a-b", "pair:a-b", ["view-a" "view-b"], ...
                ["pass-1" "pass-1"], ["obs-a" "obs-b"], ...
                [10 20; 30 40], [-2 2; 0 0; 0 0], [point point]);
            second = ProjectionSurfaceFusionFixture.record( ...
                "record-a-c", "pair:a-c", ["view-a" "view-c"], ...
                ["pass-1" "pass-2"], ["obs-a" "obs-c"], ...
                [10 20; 50 60], [-2 0; 0 -2; 0 0], [point point]);
            third = ProjectionSurfaceFusionFixture.record( ...
                "record-b-c", "pair:b-c", ["view-b" "view-c"], ...
                ["pass-1" "pass-2"], ["obs-b" "obs-c"], ...
                [30 40; 50 60], [2 0; 0 -2; 0 0], [point point]);
            request = struct( ...
                Format="ProjectionDensePairObservationRecords", Version=1, ...
                WorldFrame="sceneWorld", Records=[first second third]);
            association = ProjectionDenseObservationAssociator.associate(request);
            pointSet = ProjectionMultiRayReconstructor.reconstruct(association);
        end

        function value = record(recordId, pairId, viewIds, passIds, ...
                observationIds, source, origins, targets)
            value = struct(RecordId=recordId, PairId=pairId, ...
                ViewIds=viewIds, PassIds=passIds, ...
                ObservationIds=observationIds, ...
                SourceObservationsPixels=source, RayOriginsWorld=origins, ...
                RayVectorsWorld=targets - origins, MatchState="valid", ...
                Score=0.9, Confidence=0.9, TextureScore=0.9, ...
                NavigationWeights=[0.9 0.9], ...
                RadiometricValues=[0.4 0.42], ...
                RadiometricConsistency=0.95, ...
                VisibilityStates=["visible" "visible"], ...
                ProvisionalPointWorld=pointOrEmpty(targets), ...
                PairwiseCovarianceWorldMetersSquared=1e-4 * eye(3), ...
                ModeId="");
        end

        function modes = normalizeModes(modes)
            modes = string(modes);
            modes(strlength(modes) == 0) = "primary";
        end
    end
end

function point = pointOrEmpty(targets)
point = mean(targets, 2);
end

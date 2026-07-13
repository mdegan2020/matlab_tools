classdef ProjectionSurfaceRegistrationFixture
    %ProjectionSurfaceRegistrationFixture Deterministic S7 terrain fixtures.

    methods (Static)
        function request = cleanRequest()
            fixture = ProjectionSurfaceRegistrationFixture.fixture(false, false);
            request = fixture.Request;
        end

        function request = maskedOutlierRequest()
            fixture = ProjectionSurfaceRegistrationFixture.fixture(true, false);
            request = fixture.Request;
        end

        function request = flatRequest()
            fixture = ProjectionSurfaceRegistrationFixture.fixture(false, true);
            request = fixture.Request;
        end

        function value = truth()
            value = struct(TranslationEnuMeters=[1.2; -0.8; 2.0], Seed=37);
        end

        function result = cleanResult()
            result = ProjectionSurfaceRegistrationService.run( ...
                ProjectionSurfaceRegistrationFixture.cleanRequest());
        end

        function catalog = registeredCatalog()
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            result = ProjectionSurfaceRegistrationService.run(request);
            products = ProjectionSurfaceProductCatalog.registrationProducts( ...
                request.PointSet, request.Dem, result);
            catalog = ProjectionSurfaceProductCatalog.create( ...
                request.PointSet, {}, products);
        end

        function input = basicDemInput()
            latitude0 = 40;
            longitude0 = -75;
            east = linspace(-60, 60, 31);
            north = linspace(-60, 60, 31);
            latitude = latitude0 + north.' / 111132;
            longitude = longitude0 + east / ...
                (111320 * cosd(latitude0));
            [eastGrid, northGrid] = meshgrid(east, north);
            heights = 100 + 0.04 * eastGrid + 0.03 * northGrid + ...
                3 * sin(eastGrid / 14) + 2 * cos(northGrid / 17) + ...
                0.015 * eastGrid .* northGrid;
            frame = struct(OriginGeodeticDegreesMeters= ...
                [latitude0 longitude0 100], ...
                EnuToProjectWorldRotation=eye(3), ...
                ProjectWorldOriginMeters=zeros(3, 1), ...
                WorldFrame="sceneWorld");
            input = struct(LatitudeDegrees=latitude, ...
                LongitudeDegrees=longitude, HeightsMeters=heights, ...
                HeightReference="HAE", ...
                CallerAccuracy=struct(CE90Meters=0.5, LE90Meters=0.5), ...
                SceneFrame=frame);
        end
    end

    methods (Static, Access = private)
        function fixture = fixture(maskedOutlier, flat)
            input = ProjectionSurfaceRegistrationFixture.basicDemInput();
            if flat
                input.HeightsMeters(:) = 100;
            end
            rows = [4 5 8 10 13 16 19 22 25 27 7 12 18 24 28 9 14 20 23 26];
            columns = [5 12 20 27 8 15 24 4 13 22 28 18 6 26 10 16 21 9 29 14];
            exclusionMask = false(size(input.HeightsMeters));
            if maskedOutlier
                exclusionMask(rows(3), columns(3)) = true;
                input.ExclusionMask = exclusionMask;
            end
            dem = ProjectionDemGrid.create(input);
            base = ProjectionSurfaceFusionFixture.request();
            truth = ProjectionSurfaceRegistrationFixture.truth();
            template = base.PointSet.Points(1);
            points = repmat(template, 1, numel(rows));
            for index = 1:numel(rows)
                surface = [dem.WorldX(rows(index), columns(index)); ...
                    dem.WorldY(rows(index), columns(index)); ...
                    dem.WorldZ(rows(index), columns(index))];
                points(index).PointId = "registration-point-" + index;
                points(index).TrackId = "registration-track-" + index;
                points(index).PointWorld = ...
                    surface - truth.TranslationEnuMeters;
                points(index).CovarianceWorldMetersSquared = 0.01 * eye(3);
                points(index).PrincipalAxisSigmasMeters = 0.1 * ones(1, 3);
                points(index).ConditionNumber = 10 + index;
                points(index).Valid = true;
            end
            exclusions = ProjectionSurfaceRegistrationRequest.emptyExclusions();
            if maskedOutlier
                points(1).PointWorld(3) = points(1).PointWorld(3) + 8;
                points(2).PointWorld(3) = points(2).PointWorld(3) + 25;
                exclusions = struct(PointId=points(2).PointId, ...
                    Reason="building");
            end
            pointSet = base.PointSet;
            pointSet.Points = points;
            pointSet.GenerationId = "registration-fixture-" + ...
                string(maskedOutlier) + "-" + string(flat);
            request = struct(PointSet=pointSet, Dem=dem, ...
                HuberScaleMeters=0.2, MinimumSupport=10, ...
                EvaluateMaskSensitivity=logical(maskedOutlier), ...
                PointExclusions=exclusions, Seed=truth.Seed);
            fixture = struct(Request=request, Truth=truth);
        end
    end
end

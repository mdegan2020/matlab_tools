classdef ProjectionMotionSequence
    %ProjectionMotionSequence Build deterministic runtime motion sequences.

    properties (Constant)
        Format = "ProjectionMotionSequence"
        Version = 1
    end

    methods (Static)
        function sequence = build(scene, options)
            %build Select and order motion-imagery frames.
            if nargin < 2
                options = struct();
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
            options = ProjectionMotionSequence.options(options, scene);
            selected = ProjectionMotionSequence.selectedIndices(scene, options);
            [selected, mode, explanation, warnings] = ...
                ProjectionMotionSequence.orderIndices( ...
                scene, selected, options.CallerOrderProvided);

            sequence = struct(Format=ProjectionMotionSequence.Format, ...
                Version=ProjectionMotionSequence.Version, Available=false, ...
                Explanation="Motion imagery requires at least two frames.", ...
                LayerIndices=selected, ViewIds=strings(1, 0), ...
                PassIds=strings(1, 0), Frames=struct([]), ...
                OrderingMode=mode, OrderingExplanation=explanation, ...
                UsedStableFallback=~isempty(warnings), Warnings=warnings);
            if isempty(selected)
                return
            end

            frames = repmat(ProjectionMotionSequence.emptyFrame(), ...
                1, numel(selected));
            for position = 1:numel(selected)
                layerIndex = selected(position);
                layer = scene.layers(layerIndex);
                frames(position) = ProjectionMotionSequence.frame( ...
                    layer, layerIndex, position, numel(selected));
            end
            sequence.ViewIds = string({frames.ViewId});
            sequence.PassIds = string({frames.PassId});
            sequence.Frames = frames;
            if numel(selected) < 2
                return
            end
            sequence.Available = true;
            sequence.Explanation = "";
        end

        function [position, changed, boundary] = step( ...
                sequence, position, delta, loop)
            %step Move once through a validated sequence.
            ProjectionMotionSequence.validateSequence(sequence);
            if ~isnumeric(position) || ~isscalar(position) || ...
                    ~isfinite(position) || fix(position) ~= position || ...
                    position < 1 || position > numel(sequence.Frames)
                error("ProjectionMotionSequence:invalidPosition", ...
                    "Position must identify a frame in the sequence.");
            end
            if ~isnumeric(delta) || ~isscalar(delta) || ...
                    ~isfinite(delta) || ~any(delta == [-1 1])
                error("ProjectionMotionSequence:invalidStep", ...
                    "Motion step must be -1 or 1.");
            end
            loop = logical(loop);
            requested = position + delta;
            boundary = requested < 1 || requested > numel(sequence.Frames);
            if boundary && loop
                position = mod(requested - 1, numel(sequence.Frames)) + 1;
                changed = true;
            elseif boundary
                changed = false;
            else
                position = requested;
                changed = true;
            end
        end
    end

    methods (Static, Access = private)
        function options = options(options, scene)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionMotionSequence:invalidOptions", ...
                    "Motion sequence options must be a scalar struct.");
            end
            defaults = struct(LayerIndices=[], PassIds=strings(1, 0), ...
                IncludedViewIds=strings(1, 0), CallerOrderProvided=false);
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error("ProjectionMotionSequence:invalidOptions", ...
                        "Unknown motion sequence option %s.", names{index});
                end
                defaults.(names{index}) = options.(names{index});
            end
            if ~isempty(defaults.LayerIndices)
                indices = defaults.LayerIndices;
                if ~isnumeric(indices) || ~isvector(indices) || ...
                        any(~isfinite(indices)) || any(fix(indices) ~= indices) || ...
                        any(indices < 1) || any(indices > numel(scene.layers)) || ...
                        numel(unique(indices)) ~= numel(indices)
                    error("ProjectionMotionSequence:invalidLayerIndices", ...
                        "LayerIndices must contain unique valid layer indices.");
                end
                defaults.LayerIndices = double(indices(:).');
                defaults.CallerOrderProvided = true;
            end
            defaults.PassIds = ProjectionMotionSequence.stringFilter( ...
                defaults.PassIds, "PassIds");
            defaults.IncludedViewIds = ProjectionMotionSequence.stringFilter( ...
                defaults.IncludedViewIds, "IncludedViewIds");
            options = defaults;
        end

        function values = stringFilter(values, name)
            if isempty(values)
                values = strings(1, 0);
                return
            end
            values = reshape(string(values), 1, []);
            if any(ismissing(values)) || any(strlength(values) == 0) || ...
                    numel(unique(values)) ~= numel(values)
                error("ProjectionMotionSequence:invalidOptions", ...
                    "%s must contain unique nonempty strings.", name);
            end
        end

        function selected = selectedIndices(scene, options)
            if options.CallerOrderProvided
                selected = options.LayerIndices;
            else
                selected = 1:numel(scene.layers);
            end
            if ~isempty(options.PassIds)
                passes = string({scene.layers(selected).PassId});
                selected = selected(ismember(passes, options.PassIds));
            end
            if ~isempty(options.IncludedViewIds)
                views = string({scene.layers(selected).ViewId});
                selected = selected(ismember(views, options.IncludedViewIds));
            end
        end

        function [ordered, mode, explanation, warnings] = ...
                orderIndices(scene, selected, callerOrderProvided)
            warnings = strings(1, 0);
            if callerOrderProvided
                ordered = selected;
                mode = "caller";
                explanation = "Caller-supplied layer order is authoritative.";
                return
            end
            mode = "timeWithinPass";
            explanation = ...
                "Frames are grouped by pass and ordered by comparable acquisition time.";
            selectedPasses = string({scene.layers(selected).PassId});
            passOrder = unique(selectedPasses, "stable");
            ordered = zeros(1, 0);
            for passId = passOrder
                passIndices = selected(selectedPasses == passId);
                [passIndices, comparable] = ...
                    ProjectionMotionSequence.orderOnePass(scene, passIndices);
                if ~comparable && numel(passIndices) > 1
                    warnings(end + 1) = "Pass " + passId + ...
                        " uses stable ViewId order because acquisition clocks " + ...
                        "are missing or incomparable."; %#ok<AGROW>
                end
                ordered = [ordered passIndices]; %#ok<AGROW>
            end
            if ~isempty(warnings)
                mode = "stableFallback";
                explanation = strjoin(warnings, " ");
            end
        end

        function [indices, comparable] = orderOnePass(scene, indices)
            modes = strings(1, numel(indices));
            values = zeros(1, numel(indices));
            for ordinal = 1:numel(indices)
                time = scene.layers(indices(ordinal)).AcquisitionStartTime;
                if isempty(time)
                    modes(ordinal) = "missing";
                elseif isdatetime(time)
                    modes(ordinal) = "absolute";
                    values(ordinal) = posixtime(time);
                elseif isduration(time)
                    modes(ordinal) = "relative";
                    values(ordinal) = seconds(time);
                else
                    modes(ordinal) = "relative";
                    values(ordinal) = double(time);
                end
            end
            comparable = isscalar(unique(modes)) && modes(1) ~= "missing";
            if comparable
                [~, order] = sortrows([values(:) (1:numel(indices)).'], [1 2]);
                indices = indices(order);
            else
                viewIds = string({scene.layers(indices).ViewId});
                [~, order] = sort(viewIds);
                indices = indices(order);
            end
        end

        function frame = frame(layer, layerIndex, position, count)
            [timeMode, timeText] = ProjectionMotionSequence.timeLabel(layer);
            offsets = zeros(3, 1);
            if isfield(layer, "ViewVectorAngularOffsetsDegrees")
                offsets = double(layer.ViewVectorAngularOffsetsDegrees(:));
            end
            planeOffset = zeros(2, 1);
            if isfield(layer, "ProjectionOffsetMeters")
                planeOffset = double(layer.ProjectionOffsetMeters(:));
            end
            if any(abs(offsets) > eps) || any(abs(planeOffset) > eps)
                correction = "applied correction";
            else
                correction = "no applied correction";
            end
            frame = struct(LayerIndex=layerIndex, ...
                LayerName=string(layer.Name), ViewId=string(layer.ViewId), ...
                PassId=string(layer.PassId), Position=position, Count=count, ...
                TimeMode=timeMode, TimeText=timeText, ...
                CorrectionStatus=correction);
        end

        function [mode, label] = timeLabel(layer)
            time = layer.AcquisitionStartTime;
            if isempty(time)
                mode = "unavailable";
                label = "time unavailable";
            elseif isdatetime(time)
                mode = "absolute";
                original = "";
                if isfield(layer, "AcquisitionStartTimeOriginalText")
                    original = string(layer.AcquisitionStartTimeOriginalText);
                end
                if strlength(original) > 0
                    label = original + " UTC";
                else
                    label = string(time);
                end
            elseif isduration(time)
                mode = "relative";
                label = sprintf("%g s relative", seconds(time));
            else
                mode = "relative";
                label = sprintf("%g s relative", double(time));
            end
        end

        function frame = emptyFrame()
            frame = struct(LayerIndex=0, LayerName="", ViewId="", ...
                PassId="", Position=0, Count=0, TimeMode="", TimeText="", ...
                CorrectionStatus="");
        end

        function validateSequence(sequence)
            if ~isstruct(sequence) || ~isscalar(sequence) || ...
                    ~isfield(sequence, "Format") || ...
                    string(sequence.Format) ~= ProjectionMotionSequence.Format || ...
                    ~isfield(sequence, "Available") || ~sequence.Available || ...
                    ~isfield(sequence, "Frames") || numel(sequence.Frames) < 2
                error("ProjectionMotionSequence:invalidSequence", ...
                    "Sequence must be an available motion sequence.");
            end
        end
    end
end

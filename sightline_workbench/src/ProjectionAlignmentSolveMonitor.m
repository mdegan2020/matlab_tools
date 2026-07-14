classdef ProjectionAlignmentSolveMonitor < handle
    %ProjectionAlignmentSolveMonitor Runtime-only solve progress and work counts.

    properties (Access = private)
        ProgressFcn = []
        CancellationFcn = []
        ProgressIntervalSeconds double = 0.10
        StartTimer
        LastProgressSeconds double = -Inf
        CurrentStage string = "initializing"
        CurrentChildIndex double = 0
        RequestedChildren double = 0
        CompletedChildren double = 0
        Counts
        Timings
        CurrentOptimizerIteration double = 0
        CurrentOptimizerFunctionCount double = 0
        FirstEvaluation
        LastEvaluation
    end

    methods
        function monitor = ProjectionAlignmentSolveMonitor(runtimeControl)
            if nargin < 1 || isempty(runtimeControl)
                runtimeControl = struct();
            end
            if isfield(runtimeControl, "ProgressFcn")
                monitor.ProgressFcn = runtimeControl.ProgressFcn;
            end
            if isfield(runtimeControl, "CancellationFcn")
                monitor.CancellationFcn = runtimeControl.CancellationFcn;
            end
            if isfield(runtimeControl, "ProgressIntervalSeconds")
                monitor.ProgressIntervalSeconds = ...
                    double(runtimeControl.ProgressIntervalSeconds);
            end
            monitor.StartTimer = tic;
            monitor.Counts = struct( ...
                OptimizationCount=0, PrimaryOptimizationCount=0, ...
                OptimizerIterations=0, OptimizerFunctionEvaluations=0, ...
                DataResidualEvaluations=0, JacobianEvaluations=0, ...
                ObservationSamplingCalls=0, SampledObservationCount=0, ...
                CompiledEvidenceBuildCount=0, ...
                ComparisonFamilyEvaluations=0, ...
                ObservabilityEvaluations=0, NormalProductBuilds=0, ...
                FactorizationReuseCount=0, ...
                SensitivityChildSolvesStarted=0, ...
                SensitivityChildSolvesCompleted=0);
            monitor.Timings = struct(CompiledEvidence=0, ...
                Optimizer=0, ResidualEvaluation=0, Comparison=0, ...
                Observability=0, SensitivityDiagnostics=0);
            emptyEvaluation = struct(X=zeros(0, 1), ...
                Residuals=zeros(0, 1), Jacobian=zeros(0, 0), Valid=false);
            monitor.FirstEvaluation = emptyEvaluation;
            monitor.LastEvaluation = emptyEvaluation;
        end

        function setStage(monitor, stage, details)
            if nargin < 3
                details = struct();
            end
            monitor.CurrentStage = string(stage);
            if isfield(details, "DiagnosticChildrenRequested")
                monitor.RequestedChildren = ...
                    double(details.DiagnosticChildrenRequested);
            end
            if isfield(details, "DiagnosticChildrenCompleted")
                monitor.CompletedChildren = ...
                    double(details.DiagnosticChildrenCompleted);
            end
            if isfield(details, "DiagnosticChildIndex")
                monitor.CurrentChildIndex = ...
                    double(details.DiagnosticChildIndex);
            end
            monitor.report(details, true);
        end

        function setChildProgress(monitor, requested, completed, childIndex)
            monitor.RequestedChildren = double(requested);
            monitor.CompletedChildren = double(completed);
            monitor.CurrentChildIndex = double(childIndex);
        end

        function increment(monitor, fieldName, amount)
            fieldName = char(string(fieldName));
            if ~isfield(monitor.Counts, fieldName)
                error("ProjectionAlignmentSolveMonitor:unknownCounter", ...
                    "Unknown work counter %s.", fieldName);
            end
            monitor.Counts.(fieldName) = monitor.Counts.(fieldName) + amount;
        end

        function recordTiming(monitor, fieldName, seconds)
            fieldName = char(string(fieldName));
            if ~isfield(monitor.Timings, fieldName)
                error("ProjectionAlignmentSolveMonitor:unknownTiming", ...
                    "Unknown work timing %s.", fieldName);
            end
            monitor.Timings.(fieldName) = ...
                monitor.Timings.(fieldName) + double(seconds);
        end

        function stop = optimizerOutput(monitor, ~, optimValues, state)
            if string(state) == "init"
                monitor.increment("OptimizationCount", 1);
                if monitor.CurrentStage ~= "sensitivityChild"
                    monitor.increment("PrimaryOptimizationCount", 1);
                end
                monitor.CurrentOptimizerIteration = 0;
                monitor.CurrentOptimizerFunctionCount = 0;
            end
            if isfield(optimValues, "iteration")
                monitor.CurrentOptimizerIteration = ...
                    double(optimValues.iteration);
            end
            if isfield(optimValues, "funccount")
                monitor.CurrentOptimizerFunctionCount = ...
                    double(optimValues.funccount);
            end
            monitor.report(struct(OptimizerState=string(state)), false);
            stop = monitor.cancellationRequested();
        end

        function recordOptimizerResult(monitor, output)
            if isfield(output, "iterations")
                monitor.Counts.OptimizerIterations = ...
                    monitor.Counts.OptimizerIterations + ...
                    double(output.iterations);
            end
            if isfield(output, "funcCount")
                monitor.Counts.OptimizerFunctionEvaluations = ...
                    monitor.Counts.OptimizerFunctionEvaluations + ...
                    double(output.funcCount);
            end
        end

        function tf = cancellationRequested(monitor)
            tf = false;
            if isempty(monitor.CancellationFcn)
                return
            end
            tf = monitor.CancellationFcn();
            if ~islogical(tf) || ~isscalar(tf)
                error("ProjectionAlignmentOpkSolver:invalidCancellationResult", ...
                    "CancellationFcn must return a logical scalar.");
            end
        end

        function report(monitor, details, force)
            if nargin < 2 || isempty(details)
                details = struct();
            end
            if nargin < 3
                force = false;
            end
            elapsed = toc(monitor.StartTimer);
            if ~force && elapsed - monitor.LastProgressSeconds < ...
                    monitor.ProgressIntervalSeconds
                return
            end
            monitor.LastProgressSeconds = elapsed;
            if isempty(monitor.ProgressFcn)
                return
            end
            update = struct(Stage=monitor.CurrentStage, ...
                Iteration=monitor.CurrentOptimizerIteration, ...
                FunctionEvaluations=monitor.CurrentOptimizerFunctionCount, ...
                ElapsedSeconds=elapsed, ...
                DiagnosticChildrenRequested=monitor.RequestedChildren, ...
                DiagnosticChildrenCompleted=monitor.CompletedChildren, ...
                DiagnosticChildIndex=monitor.CurrentChildIndex, ...
                CancellationRequested=monitor.cancellationRequested());
            names = fieldnames(details);
            for index = 1:numel(names)
                update.(names{index}) = details.(names{index});
            end
            monitor.ProgressFcn(update);
        end

        function storeEvaluation(monitor, x, residuals, jacobian)
            value = struct(X=double(x(:)), ...
                Residuals=double(residuals(:)), Jacobian=double(jacobian), ...
                Valid=true);
            if ~monitor.FirstEvaluation.Valid
                monitor.FirstEvaluation = value;
            end
            monitor.LastEvaluation = value;
        end

        function [found, residuals, jacobian] = evaluation(monitor, x)
            found = monitor.LastEvaluation.Valid && ...
                isequal(monitor.LastEvaluation.X, double(x(:)));
            residuals = zeros(0, 1);
            jacobian = zeros(0, numel(x));
            if found
                residuals = monitor.LastEvaluation.Residuals;
                jacobian = monitor.LastEvaluation.Jacobian;
                monitor.increment("FactorizationReuseCount", 1);
                return
            end
            found = monitor.FirstEvaluation.Valid && ...
                isequal(monitor.FirstEvaluation.X, double(x(:)));
            if found
                residuals = monitor.FirstEvaluation.Residuals;
                jacobian = monitor.FirstEvaluation.Jacobian;
                monitor.increment("FactorizationReuseCount", 1);
            end
        end

        function diagnostics = snapshot(monitor)
            diagnostics = monitor.Counts;
            diagnostics.Stage = monitor.CurrentStage;
            diagnostics.ElapsedSeconds = toc(monitor.StartTimer);
            diagnostics.DiagnosticChildrenRequested = ...
                monitor.RequestedChildren;
            diagnostics.DiagnosticChildrenCompleted = ...
                monitor.CompletedChildren;
            diagnostics.DiagnosticChildIndex = monitor.CurrentChildIndex;
            diagnostics.CancellationRequested = ...
                monitor.cancellationRequested();
            diagnostics.StageSeconds = monitor.Timings;
        end
    end
end

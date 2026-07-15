classdef ProjectionDisjointSet < handle
    %ProjectionDisjointSet Path-compressed disjoint-set forest.

    properties (SetAccess = private)
        FindCallCount (1, 1) double = 0
        FindStepCount (1, 1) double = 0
        JoinCallCount (1, 1) double = 0
    end

    properties (Access = private)
        Parent (1, :) double = zeros(1, 0)
        Rank (1, :) double = zeros(1, 0)
    end

    methods
        function set = ProjectionDisjointSet(count)
            arguments
                count (1, 1) double {mustBeInteger, mustBeNonnegative}
            end
            set.Parent = 1:count;
            set.Rank = zeros(1, count);
        end

        function root = find(set, node)
            %find Return a representative and compress the traversed path.
            node = set.validateNode(node);
            set.FindCallCount = set.FindCallCount + 1;
            root = node;
            while set.Parent(root) ~= root
                root = set.Parent(root);
                set.FindStepCount = set.FindStepCount + 1;
            end
            while set.Parent(node) ~= node
                next = set.Parent(node);
                set.Parent(node) = root;
                node = next;
                set.FindStepCount = set.FindStepCount + 1;
            end
        end

        function [root, merged, retiredRoot] = join(set, first, second)
            %join Unite two sets using rank and deterministic root tie breaking.
            set.JoinCallCount = set.JoinCallCount + 1;
            firstRoot = set.find(first);
            secondRoot = set.find(second);
            merged = firstRoot ~= secondRoot;
            retiredRoot = secondRoot;
            if ~merged
                root = firstRoot;
                return
            end
            firstRank = set.Rank(firstRoot);
            secondRank = set.Rank(secondRoot);
            if firstRank < secondRank || ...
                    (firstRank == secondRank && firstRoot > secondRoot)
                root = secondRoot;
                retiredRoot = firstRoot;
            else
                root = firstRoot;
                retiredRoot = secondRoot;
            end
            set.Parent(retiredRoot) = root;
            if firstRank == secondRank
                set.Rank(root) = set.Rank(root) + 1;
            end
        end

        function roots = roots(set, nodes)
            %roots Return compressed representatives for the supplied nodes.
            nodes = reshape(double(nodes), 1, []);
            roots = zeros(size(nodes));
            for index = 1:numel(nodes)
                roots(index) = set.find(nodes(index));
            end
        end

        function value = diagnostics(set)
            %diagnostics Return bounded algorithmic work counters.
            value = struct(FindCalls=set.FindCallCount, ...
                FindSteps=set.FindStepCount, JoinCalls=set.JoinCallCount);
        end
    end

    methods (Access = private)
        function node = validateNode(set, node)
            if ~isnumeric(node) || ~isscalar(node) || ~isfinite(node) || ...
                    fix(node) ~= node || node < 1 || node > numel(set.Parent)
                error("ProjectionDisjointSet:invalidNode", ...
                    "Node must be an integer in the disjoint-set range.");
            end
            node = double(node);
        end
    end
end

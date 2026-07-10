classdef ProjectionViewerLruCache < handle
    %ProjectionViewerLruCache Byte-bounded runtime-only least-recently-used cache.

    properties (SetAccess = private)
        MaxBytes double
        TotalBytes double = 0
        AccessCounter uint64 = uint64(0)
        Entries struct
        EvictionCount double = 0
    end

    methods
        function cache = ProjectionViewerLruCache(maxBytes)
            if nargin < 1
                maxBytes = 256 * 1024 ^ 2;
            end
            cache.MaxBytes = ProjectionViewerLruCache.validateByteCount( ...
                maxBytes, "maxBytes", false);
            cache.Entries = ProjectionViewerLruCache.emptyEntries();
        end

        function [found, value] = get(cache, key)
            %get Return and touch an entry by stable string key.
            key = ProjectionViewerLruCache.validateKey(key);
            entryIndex = [];
            if ~isempty(cache.Entries)
                entryIndex = find([cache.Entries.Key] == key, 1, "first");
            end
            found = ~isempty(entryIndex);
            if ~found
                value = struct();
                return
            end
            cache.AccessCounter = cache.AccessCounter + 1;
            cache.Entries(entryIndex).LastAccess = cache.AccessCounter;
            value = cache.Entries(entryIndex).Value;
        end

        function stored = put(cache, key, value, byteCount)
            %put Insert or replace an entry and evict least-recent entries.
            key = ProjectionViewerLruCache.validateKey(key);
            byteCount = ProjectionViewerLruCache.validateByteCount( ...
                byteCount, "byteCount", true);
            existingIndex = [];
            if ~isempty(cache.Entries)
                existingIndex = find([cache.Entries.Key] == key, 1, "first");
            end
            if ~isempty(existingIndex)
                cache.TotalBytes = cache.TotalBytes - ...
                    cache.Entries(existingIndex).Bytes;
                cache.Entries(existingIndex) = [];
            end
            if byteCount > cache.MaxBytes
                stored = false;
                return
            end

            cache.evictFor(byteCount);
            cache.AccessCounter = cache.AccessCounter + 1;
            entry = struct(Key=key, Value=value, Bytes=byteCount, ...
                LastAccess=cache.AccessCounter);
            cache.Entries(end + 1) = entry;
            cache.TotalBytes = cache.TotalBytes + byteCount;
            stored = true;
        end

        function clear(cache)
            %clear Remove all cached values and reset diagnostics.
            cache.TotalBytes = 0;
            cache.AccessCounter = uint64(0);
            cache.Entries = ProjectionViewerLruCache.emptyEntries();
            cache.EvictionCount = 0;
        end

        function diagnostics = diagnostics(cache)
            diagnostics = struct(EntryCount=numel(cache.Entries), ...
                TotalBytes=cache.TotalBytes, MaxBytes=cache.MaxBytes, ...
                EvictionCount=cache.EvictionCount);
        end
    end

    methods (Access = private)
        function evictFor(cache, incomingBytes)
            while ~isempty(cache.Entries) && ...
                    cache.TotalBytes + incomingBytes > cache.MaxBytes
                [~, entryIndex] = min([cache.Entries.LastAccess]);
                cache.TotalBytes = cache.TotalBytes - ...
                    cache.Entries(entryIndex).Bytes;
                cache.Entries(entryIndex) = [];
                cache.EvictionCount = cache.EvictionCount + 1;
            end
        end
    end

    methods (Static, Access = private)
        function entries = emptyEntries()
            entries = struct("Key", {}, "Value", {}, "Bytes", {}, ...
                "LastAccess", {});
        end

        function key = validateKey(key)
            key = string(key);
            if ~isscalar(key) || ismissing(key) || strlength(key) == 0
                error("ProjectionViewerLruCache:invalidKey", ...
                    "Cache keys must be nonempty string scalars.");
            end
        end

        function value = validateByteCount(value, name, allowZero)
            minimum = double(~allowZero);
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < minimum || fix(value) ~= value
                error("ProjectionViewerLruCache:invalidByteCount", ...
                    "%s must be a %s integer byte count.", name, ...
                    ProjectionViewerLruCache.positiveText(allowZero));
            end
            value = double(value);
        end

        function text = positiveText(allowZero)
            if allowZero
                text = "nonnegative";
            else
                text = "positive";
            end
        end
    end
end

function runs = findValidRuns(mask)
% findValidRuns  在逻辑掩码中查找所有 "true 连续段" 的起止下标

mask = logical(mask(:));
d = diff([false; mask; false]);     % +1 = 段起点之前；-1 = 段终点之后
runs = [find(d == 1), find(d == -1) - 1];
end

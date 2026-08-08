function writeCorrectedDatFiles(dsArt, calResults, outDir, cfg) %#ok<INUSD>
% writeCorrectedDatFiles  输出校准后的 .dat 文件

if ~isfolder(outDir)
    mkdir(outDir);
end

for i = 1:numel(dsArt)
    fp = fullfile(outDir, dsArt(i).name);          % 文件名与人工数据一致
    data = [calResults(i).t(:), calResults(i).R(:)];
    writematrix(data, fp, 'FileType', 'text', 'Delimiter', 'tab');
end

fprintf('  已输出 %d 个校准后的 .dat 文件（文件名与人工数据集一一对应）。\n', ...
    numel(dsArt));
end

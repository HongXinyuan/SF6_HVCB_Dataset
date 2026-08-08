% Read the Excel file 
file_path = 'xxx.xlsx';
data = readtable(file_path);

% Get the size of the data
[num_rows, num_cols] = size(data);

% Set the number of rows per group
group_size = 50;

% Calculate the number of groups needed
num_groups = ceil(num_rows / group_size);

% Create a new table to store the average values
avg_table = table();

% Process each column
for col = 1:num_cols
    % Extract current column data (assuming numeric data)
    column_data = table2array(data(:, col));
    
    % Used to store the average value of each group
    group_means = zeros(num_groups, 1);
    
    % Calculate the average value for each group of data
    for group = 1:num_groups
        % Calculate the start and end indices for the current group
        start_idx = (group - 1) * group_size + 1;
        end_idx = min(group * group_size, num_rows);
        
        % Extract data for the current group
        group_data = column_data(start_idx:end_idx);
        
        % Calculate the average value
        group_means(group) = mean(group_data);
    end
    
    % Add the average values to the new table
    col_name = data.Properties.VariableNames{col};
    avg_table.(col_name) = group_means;
end

% Save as a new Excel file
output_file = 'yyy.xlsx';
writetable(avg_table, output_file);

% Display the results
disp('Processing complete!');
disp(['Original data rows: ', num2str(num_rows)]);
disp(['Average value data rows: ', num2str(num_groups)]);
disp(['Output file: ', output_file]);

% Display a preview of the first few rows of the results
disp('First 5 rows of average results:');
disp(head(avg_table, 5));
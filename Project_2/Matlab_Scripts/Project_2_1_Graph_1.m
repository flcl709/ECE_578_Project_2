clear; clc; close all;

% ----------------------------------------------------
% 1. Load the AS type datasets
% ----------------------------------------------------
data_2021 = readtable('20210401.as2types.txt'); 
data_2015 = readtable('20150801.as2types.txt');

data_2021.Properties.VariableNames = {'AS','SOURCE','TYPE'};
data_2015.Properties.VariableNames = {'AS','SOURCE','TYPE'};

% Normalize TYPE values
data_2021.TYPE(strcmp(data_2021.TYPE,'Enterprise')) = {'Stubbed'};
data_2015.TYPE(strcmp(data_2015.TYPE,'Enterprise')) = {'Stubbed'};
data_2021.TYPE(strcmp(data_2021.TYPE,'Content')) = {'Multi-Homed'};
data_2015.TYPE(strcmp(data_2015.TYPE,'Content')) = {'Multi-Homed'};

% ----------------------------------------------------
% 2. University of Arizona color palette
% ----------------------------------------------------
ua_colors = [
    0.8039 0      0.2157;   % Arizona Red
    0      0.1176 0.3843;   % Arizona Blue
    0.6    0.6    0.6      % Gray (for 3rd category)
];

% ----------------------------------------------------
% 3. Define a consistent ordering of TYPE labels
% ----------------------------------------------------
canonicalTypes = {'Stubbed','Multi-Homed','Transit'};  
% If other types appear, they get appended automatically.

% Get full set of types across both datasets
allTypes = unique([data_2015.TYPE; data_2021.TYPE]);
missing = setdiff(allTypes, canonicalTypes);
typeOrder = [canonicalTypes(:); missing];   % unified type ordering

% ----------------------------------------------------
% 4. Create figure
% ----------------------------------------------------
figure('Position',[150 150 1300 500]);

% ----------------------------------------------------
% 5. Plot each year using helper
% ----------------------------------------------------
subplot(1,2,1);
plotPie(data_2015.TYPE, typeOrder, ua_colors, '2015 AS Classification Distribution');

subplot(1,2,2);
plotPie(data_2021.TYPE, typeOrder, ua_colors, '2021 AS Classification Distribution');

% ----------------------------------------------------
% 6. Save figure
% ----------------------------------------------------
saveas(gcf,'Matlab_Figures/Project_2_1_Graph_1.png');


% ============================================================
% Helper Function: Plot Pie Chart with UA Colors + Legend
% ============================================================
function plotPie(typeColumn, typeOrder, colors, plotTitle)

% Reorder categories to consistent canonical ordering
[counts, labels] = reorderAndCount(typeColumn, typeOrder);

% Percentages
pct = 100 * counts / sum(counts);
legendText = labels + " (" + string(round(pct,1)) + "%)";

% Plot pie chart with no slice labels
emptyLabels = repmat({''}, length(counts), 1);
pie(counts, emptyLabels);
colormap(colors);

title(plotTitle, 'FontSize',18);
set(gca,'FontSize',14);

legend(legendText, ...
    'Location','southoutside', ...
    'Orientation','vertical', ...
    'FontSize',14);

end


% ============================================================
% Helper Function: Count Types in Stable Order
% ============================================================
function [counts, orderedLabels] = reorderAndCount(typeColumn, typeOrder)

% Convert to categorical with fixed ordering
c = categorical(typeColumn, typeOrder);

% Count occurrences in each category
[countsRaw, labelsRaw] = groupcounts(c);

% Now reorder according to typeOrder
% Initialize full count vector
counts = zeros(length(typeOrder),1);
orderedLabels = string(typeOrder);

% Map groupcounts results into canonical ordering
for i = 1:length(labelsRaw)
    label = string(labelsRaw(i));
    idx = find(strcmp(typeOrder, label));
    if ~isempty(idx)
        counts(idx) = countsRaw(i);
    end
end

% Remove any zero-count trailing entries
zeroMask = counts == 0;
counts(zeroMask) = [];
orderedLabels(zeroMask) = [];

end
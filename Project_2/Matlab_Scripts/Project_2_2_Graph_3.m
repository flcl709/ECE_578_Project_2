clc; close all;

% ----------------------------------------------------
% 1. Load TAB-delimited .txt RouteViews data
% ----------------------------------------------------
opts = detectImportOptions('routeviews-rv2-20251110-1200.txt', ...
                           'FileType','text');
opts.Delimiter     = '\t';
opts.VariableTypes = {'string','double','double'};

data = readtable('routeviews-rv2-20251110-1200.txt', opts);
data.Properties.VariableNames = {'prefix','prefixLength','AS'};

% ----------------------------------------------------
% 2. Convert AS column to 1..N compact indices
% ----------------------------------------------------
AS_vals = data.AS;                 % numeric ASN values
[unique_AS, ~, AS_idx] = unique(AS_vals);  
% AS_idx guaranteed to be 1..N integers for accumarray

% ----------------------------------------------------
% 3. Compute IP space per prefix
% ----------------------------------------------------
prefixLen = data.prefixLength;
ipSpace   = 2.^(32 - prefixLen);

% ----------------------------------------------------
% 4. Sum total IP space per AS
% ----------------------------------------------------
totalSpace = accumarray(AS_idx, ipSpace);

% ----------------------------------------------------
% 5. Compute safe log2 bins
% ----------------------------------------------------
binIndex = ceil(log2(totalSpace));

% Clean invalid / zero / negative bins
binIndex(~isfinite(binIndex)) = 1;
binIndex(binIndex < 1) = 1;

% Ensure numeric column vector
binIndex = double(binIndex(:));
maxBin   = max(binIndex);

% ----------------------------------------------------
% 6. Histogram of AS counts per bin
% ----------------------------------------------------
counts = accumarray(binIndex, 1, [maxBin 1], @sum, 0);

% ----------------------------------------------------
% 7. UA Blue Histogram with 2^k axis labels
% ----------------------------------------------------
ua_blue = [0 0.1176 0.3843];  % UA Blue RGB

figure('Position',[200 200 1200 600]);
bar(counts, 'FaceColor', ua_blue);

% Create xtick labels: 2^{0}, 2^{1}, ..., 2^{maxBin-1}
n = numel(counts);
xticks(1:n);
xticklabels(arrayfun(@(k) sprintf('2^{%d}', k-1), 1:n, 'UniformOutput', false));

xlabel('IP Space Bin (2^{k})','FontSize',14);
ylabel('Number of ASes','FontSize',14);
title('AS Distribution by Total IP Space (log_2 bins)','FontSize',18);
set(gca,'FontSize',14);

% ----------------------------------------------------
% 8. Save figure
% ----------------------------------------------------
saveas(gcf, 'Matlab_Figures/Project_2_2_Graph_3.png');

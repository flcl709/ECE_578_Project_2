clear; clc; close all;

% ----------------------------------------------------
% 1. Load AS relationship data (pipe-delimited)
% ----------------------------------------------------
opts = detectImportOptions('20241101.as-rel2.txt', 'FileType','text');
opts.Delimiter = '|';
opts.VariableTypes = {'double','double','double','string'};
data = readtable('20241101.as-rel2.txt', opts);

% Extract fields
AS1 = data.Var1;
AS2 = data.Var2;
rel = data.Var3; % -1 = p2c, 0 = p2p

% ----------------------------------------------------
% 2. Build compact AS index set
% ----------------------------------------------------
allAS = [AS1; AS2];
[uniqueAS, ~, idxAS] = unique(allAS);  
N = numel(uniqueAS);

% Split indices for each role
idxAS1 = idxAS(1:numel(AS1));
idxAS2 = idxAS(numel(AS1)+1:end);

% ----------------------------------------------------
% 3. Vectorized relationship construction
% ----------------------------------------------------
% provider → customer (p2c: rel = -1)
mask_p2c = rel == -1;
p_idx1 = idxAS1(mask_p2c); % providers
p_idx2 = idxAS2(mask_p2c); % customers

% peer ↔ peer (p2p: rel = 0)
mask_p2p = rel == 0;
peerA = idxAS1(mask_p2p);
peerB = idxAS2(mask_p2p);

% ----------------------------------------------------
% 4. Compute customer counts, provider counts, peer counts (vectorized)
% ----------------------------------------------------
customerCount  = accumarray(p_idx1, 1, [N 1], @sum, 0); % AS has customers
providerCount  = accumarray(p_idx2, 1, [N 1], @sum, 0); % AS has providers
peerCountA     = accumarray(peerA, 1, [N 1], @sum, 0);
peerCountB     = accumarray(peerB, 1, [N 1], @sum, 0);
peerCount      = peerCountA + peerCountB;

% ----------------------------------------------------
% 5. Classify AS Type (optimized definitions)
% ----------------------------------------------------
% Transit: ≥1 customer
isTransit = customerCount >= 1;

% Content: 0 customers, ≥1 peer, ≥1 provider
isContent = (customerCount == 0) & (peerCount >= 1) & (providerCount >= 1);

% Enterprise: everything else
isEnterprise = ~(isTransit | isContent);

transitCnt     = sum(isTransit);
contentCnt     = sum(isContent);
enterpriseCnt  = sum(isEnterprise);

counts = [transitCnt, contentCnt, enterpriseCnt];
labels = {'Transit','Content','Enterprise'};

% ----------------------------------------------------
% 6. Build legend text (percentages)
% ----------------------------------------------------
pct = 100 * counts / sum(counts);
legendText = arrayfun(@(i) sprintf('%s (%.1f%%)', labels{i}, pct(i)), ...
                      1:numel(labels), 'UniformOutput', false);

% UA color scheme
ua_blue = [0 0.1176 0.3843];
ua_red  = [0.8 0 0];
ua_gray = [0.6 0.6 0.6];
colors  = [ua_blue; ua_red; ua_gray];

% ----------------------------------------------------
% 7. Plot (pie chart with legend beneath)
% ----------------------------------------------------
figure('Position',[200 200 1200 600]);

p = pie(counts);
colormap(colors);

% Remove slice text labels
textHandles = findobj(p, 'Type', 'text');
set(textHandles, 'String', '');

title('AS Type Distribution (Derived from AS Relationships)', 'FontSize', 18);

legend(legendText, 'Location','southoutside', ...
       'Orientation','vertical', 'FontSize',14);

% ----------------------------------------------------
% 8. Save figure (root-level)
% ----------------------------------------------------
saveas(gcf, 'Matlab_Figures/Project_2_2_Graph_4.png');

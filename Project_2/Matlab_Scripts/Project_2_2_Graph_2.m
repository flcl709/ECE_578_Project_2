clear; clc; close all;

% Load CAIDA AS relationship data
data = readtable('20241101.as-rel2.txt');

% Columns:
% p2c link: <provider-AS>|<customer-AS>| -1 |<source>
% p2p link: <peer-AS>|<peer-AS>| 0  |<source>

as1 = data.Var1;
as2 = data.Var2;
rel = data.Var3;

% Build ASN -> compact index mapping using vectorized ismember
uniqueAS = unique([as1; as2]);
n = numel(uniqueAS);

[~, idx1] = ismember(as1, uniqueAS);
[~, idx2] = ismember(as2, uniqueAS);

% --------------------------
% Extract & dedupe edges
% --------------------------
p2c_mask = (rel == -1);
p2p_mask = (rel == 0);

% Provider -> Customer directed edges, then dedupe
p2c_edges = [idx1(p2c_mask), idx2(p2c_mask)];
p2c_edges = unique(p2c_edges, 'rows');

% Peer <-> Peer edges, dedupe undirected
p2p_edges = [idx1(p2p_mask), idx2(p2p_mask)];
p2p_edges = unique(sort(p2p_edges, 2), 'rows');  % undirected unique

% --------------------------
% Degree calculations
% --------------------------

% Customer degree: how many customers each AS has (as provider)
customerDegree = accumarray(p2c_edges(:,1), 1, [n 1], @sum, 0);

% Provider degree: how many providers each AS has (as customer)
providerDegree = accumarray(p2c_edges(:,2), 1, [n 1], @sum, 0);

% Peer degree: count unique peers per AS (undirected)
p2p_sym = [p2p_edges; p2p_edges(:,[2 1])];
peerDegree = accumarray(p2p_sym(:,1), 1, [n 1], @sum, 0);

% Global degree: unique neighbors considering both p2c and p2p
p2c_undir = unique(sort(p2c_edges, 2), 'rows');
all_undir = unique([p2c_undir; p2p_edges], 'rows');
all_sym   = [all_undir; all_undir(:,[2 1])];
globalDegree = accumarray(all_sym(:,1), 1, [n 1], @sum, 0);

% --------------------------
% Plot histograms (2x2)
% --------------------------
figure('Position',[200 200 1200 900]);

plotHistogramFast(globalDegree,   2,2,1, 'Global Degree');
plotHistogramFast(customerDegree, 2,2,2, 'Customer Degree');
plotHistogramFast(peerDegree,     2,2,3, 'Peer Degree');
plotHistogramFast(providerDegree, 2,2,4, 'Provider Degree');

% Link y-axes for fair comparison
ax = findall(gcf,'type','axes');
linkaxes(ax,'y');

% Save figure
saveas(gcf, 'Matlab_Figures/Project_2_2_Graph_2.png');


function plotHistogramFast(degreeVec, plotPosX, plotPosY, plotNum, plotTitle)

    % Bin definitions:
    % 0, 1, 2-5, 6-100, 101-500, 501-1000, 1001+
    edges = [-0.5 0.5 1.5 5.5 100.5 500.5 1000.5 inf];

    binIdx = discretize(degreeVec, edges);
    binCount = accumarray(binIdx(~isnan(binIdx)), 1, [7 1], @sum, 0);

    subplot(plotPosX, plotPosY, plotNum);

    ua_blue = [0 0.1176 0.3843];  % University of Arizona Blue
    bar(binCount, 'FaceColor', ua_blue);

    xticklabels({'0','1','2–5','6–100','101–500','501–1000','1001+'});
    ylabel('AS Count','FontSize',14);
    title(plotTitle,'FontSize',18);

    set(gca,'FontSize',14);

end

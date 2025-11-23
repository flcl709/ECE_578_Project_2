% Section 2.4 – Extra Credit: Customer Cone Ranking Table (Optimized A)
% Author: Jacob Hollidge
%
% Outputs top-N ASes by customer cone size and saves CSV.
% Table columns match Project_2.4.png structure.

clear; clc; close all;

%% -------------------------
% Files in current directory
% -------------------------
rel_file = '20241101.as-rel2.txt';
pfx_file = 'routeviews-rv2-20251110-1200.txt';
org_file = '20251001.as-org2info1.txt';

assert(exist(rel_file,'file')==2, 'Missing %s', rel_file);
assert(exist(pfx_file,'file')==2, 'Missing %s', pfx_file);
assert(exist(org_file,'file')==2, 'Missing %s', org_file);

topN = 15;

%% -------------------------
% 1) Load AS relationship data (vectorized read)
% Format: AS1|AS2|relType|source
% relType: -1 provider->customer, 0 peer
% -------------------------
opts = detectImportOptions(rel_file, 'FileType','text');
opts.Delimiter = '|';
opts.VariableTypes = {'double','double','double','string'};
relT = readtable(rel_file, opts);

AS1 = relT.Var1;
AS2 = relT.Var2;
relType = relT.Var3;

% Keep only valid numeric rows
good = isfinite(AS1) & isfinite(AS2) & isfinite(relType) & (AS1 ~= AS2);
AS1 = AS1(good);
AS2 = AS2(good);
relType = relType(good);

% Compact AS indexing
allAS_raw = [AS1; AS2];
[allAS, ~, idxAll] = unique(allAS_raw);
N = numel(allAS);

idxAS1 = idxAll(1:numel(AS1));
idxAS2 = idxAll(numel(AS1)+1:end);

%% -------------------------
% 2) Build provider -> customer adjacency (p2c) using accumarray
% -------------------------
mask_p2c = (relType == -1);
provIdx = idxAS1(mask_p2c);
custIdx = idxAS2(mask_p2c);

% children{p} = unique list of customers of provider p
children = accumarray(provIdx, custIdx, [N 1], @(v){unique(v)}, {[]});

%% -------------------------
% 3) Compute global degree (undirected) vectorized
% -------------------------
edges_i = [idxAS1; idxAS2];
edges_j = [idxAS2; idxAS1];
adj = accumarray(edges_i, edges_j, [N 1], @(v){unique(v)}, {[]});
AS_degree = cellfun(@numel, adj);  % global degree per AS

total_ASes_rel = N;

%% -------------------------
% 4) Load prefix → AS mapping (tab/space delimited)
% Format: prefix <tab> prefixLen <tab> ASN
% -------------------------
fid = fopen(pfx_file,'r');
Tp = textscan(fid, '%s %f %f', ...
    'Delimiter', {'\t',' '}, 'MultipleDelimsAsOne', true);
fclose(fid);

prefix_len = Tp{2};
prefix_asn = Tp{3};

% drop invalid rows
goodP = isfinite(prefix_len) & isfinite(prefix_asn);
prefix_len = prefix_len(goodP);
prefix_asn = prefix_asn(goodP);

ip_space = 2.^(32 - prefix_len);

total_prefixes = numel(prefix_len);
total_IPs      = sum(ip_space);

% Map prefix ASNs into compact indices (0 if not in rel graph)
[tfP, prefix_idx] = ismember(prefix_asn, allAS);

% Direct per-AS prefix count and IP space
direct_prefix_count = accumarray(prefix_idx(tfP), 1, [N 1], @sum, 0);
direct_IP_space     = accumarray(prefix_idx(tfP), ip_space(tfP), [N 1], @sum, 0);

%% -------------------------
% 5) Load AS -> org name mapping (vectorized)
% org2info format: two sections separated by blank line
% Section 1: ASN|...|...|OrgID|...
% Section 2: OrgID|OrgName|...
% -------------------------
org_raw = fileread(org_file);
lines = regexp(org_raw, '\n', 'split');

blankLine = find(cellfun(@isempty, strtrim(lines)), 1);
if isempty(blankLine)
    blankLine = numel(lines)+1; % fallback
end
sec1 = lines(1:blankLine-1);
sec2 = lines(blankLine+1:end);

% Section 1: ASN -> OrgID
asn_list = [];
orgid_list = strings(0,1);
for i = 1:numel(sec1)
    L = strtrim(sec1{i});
    if isempty(L) || startsWith(L,'#'), continue; end
    parts = split(L,'|');
    if numel(parts) < 4, continue; end
    asn = str2double(parts{1});
    if ~isfinite(asn), continue; end
    asn_list(end+1,1) = asn; %#ok<SAGROW>
    orgid_list(end+1,1) = string(parts{4}); %#ok<SAGROW>
end

% Section 2: OrgID -> OrgName
orgid2_list = strings(0,1);
orgname_list = strings(0,1);
for i = 1:numel(sec2)
    L = strtrim(sec2{i});
    if isempty(L) || startsWith(L,'#'), continue; end
    parts = split(L,'|');
    if numel(parts) < 2, continue; end
    orgid2_list(end+1,1) = string(parts{1}); %#ok<SAGROW>
    orgname_list(end+1,1) = string(parts{2}); %#ok<SAGROW>
end

% Convert to lookup via ismember later
%% -------------------------
% 6) Customer cone computation (exact BFS w/ stamp visited)
% Also aggregates prefixes/IPs via precomputed direct vectors.
% -------------------------
cone_AS_count     = zeros(N,1);
cone_prefix_count = zeros(N,1);
cone_IPs          = zeros(N,1);

visitedStamp = zeros(N,1,'uint32');
stamp = uint32(0);
queue = zeros(N,1); % reused BFS queue

for s = 1:N
    kids = children{s};
    if isempty(kids)
        continue;
    end

    stamp = stamp + 1;
    head = 1;
    tail = numel(kids);
    queue(1:tail) = kids;

    while head <= tail
        v = queue(head); head = head + 1;
        if visitedStamp(v) == stamp
            continue;
        end
        visitedStamp(v) = stamp;

        vkids = children{v};
        if ~isempty(vkids)
            klen = numel(vkids);
            queue(tail+1:tail+klen) = vkids;
            tail = tail + klen;
        end
    end

    coneNodes = find(visitedStamp == stamp);

    cone_AS_count(s)     = numel(coneNodes);
    cone_prefix_count(s) = sum(direct_prefix_count(coneNodes));
    cone_IPs(s)          = sum(direct_IP_space(coneNodes));
end

pct_ASes     = (cone_AS_count     / total_ASes_rel) * 100;
pct_prefixes = (cone_prefix_count / total_prefixes) * 100;
pct_IPs      = (cone_IPs          / total_IPs) * 100;

%% -------------------------
% 7) Rank by customer cone (# ASes)
% -------------------------
[~, idxRank] = sort(cone_AS_count, 'descend');
idxRank = idxRank(1:min(topN, numel(idxRank)));

AS_numbers = allAS(idxRank);
AS_deg     = AS_degree(idxRank);

% Org lookup vectorized:
% ASN -> OrgID
[tfOrg, locOrg] = ismember(AS_numbers, asn_list);
orgIDs = strings(size(AS_numbers));
orgIDs(tfOrg) = orgid_list(locOrg(tfOrg));
orgIDs(~tfOrg) = "Unknown";

% OrgID -> OrgName
[tfName, locName] = ismember(orgIDs, orgid2_list);
AS_orgs = orgIDs;
AS_orgs(tfName) = orgname_list(locName(tfName));

Rank = (1:numel(idxRank)).';

%% -------------------------
% 8) Build final table (matches Project_2.4.png)
% -------------------------
tbl = table( ...
    Rank, AS_numbers, AS_orgs, AS_deg, ...
    cone_AS_count(idxRank), cone_prefix_count(idxRank), cone_IPs(idxRank), ...
    pct_ASes(idxRank), pct_prefixes(idxRank), pct_IPs(idxRank), ...
    'VariableNames', { ...
        'Rank', 'AS_Number', 'Organization', 'AS_Degree', ...
        'Cone_ASes', 'Cone_Prefixes', 'Cone_IPs', ...
        'Pct_ASes', 'Pct_Prefixes', 'Pct_IPs' ...
    });

%% Save CSV
out_csv = 'Matlab_Figures\Project_2_4_Table_2.csv';
writetable(tbl, out_csv);
fprintf('Saved: %s\n', out_csv);

disp(tbl);

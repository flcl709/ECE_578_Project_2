clear; clc; close all;

as_rel_file = '20241101.as-rel2.txt';
as_org_file = '20251001.as-org2info1.txt';
top_n = 50;
target_size = 10;

% ----------------------------------------------------
% 1. Load AS Relationship File (p2c + p2p)
% ----------------------------------------------------
opts = detectImportOptions(as_rel_file, 'FileType','text');
opts.Delimiter = '|';
opts.VariableTypes = {'double','double','double','string'};
relData = readtable(as_rel_file, opts);

AS1 = relData.Var1;
AS2 = relData.Var2;
rel = relData.Var3;   % -1 = p2c, 0 = p2p

% ----------------------------------------------------
% 2. Build compact AS index set
% ----------------------------------------------------
allAS = [AS1; AS2];
[uniqueAS, ~, idxAS] = unique(allAS);
N = numel(uniqueAS);

% Match indices back to AS1, AS2
idxAS1 = idxAS(1:numel(AS1));
idxAS2 = idxAS(numel(AS1)+1:end);

% ----------------------------------------------------
% 3. Build adjacency list (vectorized)
% ----------------------------------------------------
% We store edges undirected for degree computation
edges_i = [idxAS1; idxAS2];
edges_j = [idxAS2; idxAS1];

% Build adjacency lists using accumarray
adj = accumarray(edges_i, edges_j, [N 1], @(x){unique(x)}, {});

% ----------------------------------------------------
% 4. Compute global degrees
% ----------------------------------------------------
degrees = cellfun(@numel, adj);

% Sort AS by degree
degTable = [uniqueAS, degrees];
degSorted = sortrows(degTable, -2);

fprintf("Total AS entries with degree info: %d\n", size(degSorted,1));

% ----------------------------------------------------
% 5. Greedy Clique Heuristic (top_n ASes only)
% ----------------------------------------------------
rankedAS = degSorted(1:min(top_n,end), 1);
clique = [];

for i = 1:length(rankedAS)
    candidateASN = rankedAS(i);

    % Convert ASN → internal index
    ci = find(uniqueAS == candidateASN);

    if isempty(clique)
        clique = candidateASN;
        continue;
    end

    % All ASNs in current clique must be neighbors
    cliqueIdx = arrayfun(@(asn)find(uniqueAS==asn), clique);
    neighbors = adj{ci};

    if all(ismember(cliqueIdx, neighbors))
        clique = [clique; candidateASN];
    end

    if numel(clique) >= target_size
        break;
    end
end

fprintf("Inferred Tier-1 Clique size: %d\n", numel(clique));

% ----------------------------------------------------
% 6. Load AS → Organization mapping
% ----------------------------------------------------
org_raw = fileread(as_org_file);
lines = regexp(org_raw, '\n', 'split');

% The .as-org2info.txt format has:
% Section 1: AS → OrgID
% Blank line
% Section 2: OrgID → OrgName

blankLine = find(cellfun(@isempty, strtrim(lines)), 1);

section1 = lines(1:blankLine-1);
section2 = lines(blankLine+1:end);

% Parse Section 1: ASN | OrgID | ...
asn_to_orgid = containers.Map('KeyType','int32','ValueType','char');
for i = 1:numel(section1)
    L = strtrim(section1{i});
    if isempty(L) || startsWith(L,'#'), continue; end
    parts = strsplit(L, '|');
    if numel(parts) < 4, continue; end
    asn = str2double(parts{1});
    orgid = parts{4};
    if ~isnan(asn)
        asn_to_orgid(asn) = orgid;
    end
end

% Parse Section 2: OrgID | OrgName | ...
orgid_to_name = containers.Map('KeyType','char','ValueType','char');
for i = 1:numel(section2)
    L = strtrim(section2{i});
    if isempty(L) || startsWith(L,'#'), continue; end
    parts = strsplit(L, '|');
    if numel(parts) < 2, continue; end
    orgid = parts{1};
    orgname = parts{2};
    orgid_to_name(orgid) = orgname;
end

% ----------------------------------------------------
% 7. Build output table (top 10 Tier-1 ASes)
% ----------------------------------------------------
result_AS   = clique(1:min(10,end));
result_Deg  = zeros(size(result_AS));
result_Org  = strings(size(result_AS));

for i = 1:numel(result_AS)
    asn = result_AS(i);
    result_Deg(i) = degrees(uniqueAS == asn);

    if isKey(asn_to_orgid, asn)
        orgid = asn_to_orgid(asn);
        if isKey(orgid_to_name, orgid)
            result_Org(i) = orgid_to_name(orgid);
        else
            result_Org(i) = orgid;
        end
    else
        result_Org(i) = "Unknown";
    end
end

T = table(result_AS, result_Org, result_Deg, ...
          'VariableNames', {'AS_Number','Organization','Degree'});

% ----------------------------------------------------
% 8. Save CSV
% ----------------------------------------------------
writetable(T, 'Matlab_Figures/Project_2_3_Table_1.csv');

% ----------------------------------------------------
% 9. Print to console
% ----------------------------------------------------
fprintf("\nTop Tier-1 ASes:\n");
fprintf("%-10s %-40s %-10s\n", 'AS', 'Organization', 'Degree');
fprintf("%s\n", repmat('-', 1, 70));

for i = 1:height(T)
    fprintf('AS%-9d %-40s %d\n', T.AS_Number(i), T.Organization(i), T.Degree(i));
end

% This script reproduces the results from Table 2, scenario 3. 
%
% MCS computation for the strain design of a 2,3-butanediol production host
% using co-feeding
%
% We enumerate all Minimal Gene Cut Sets up to the size of 6 for the
% strongly growth coupled production of 2,3-butanediol from glucose and/or
% acetate and/or glycerol with E. coli. Compared to the first scenario 
% ("benchmark"), (1) acetate and glycerol supply are added to the model as 
% substrate alternatives and glucose is no longer a mandatory substrate. 
% Now any combination of the three substrates may be used. All three uptake 
% reactions are defined as "knock-in-able" so that the MCS algorithm can 
% choose their addition individually. (2) a second Target region is introduced 
% to correctly determine the demanded yield threshold in a case differentiation 
% (For details, read chapter "results"). GPR rule compression and network 
% compression are enabled to speed up the MCS computation.
%
% % required files/models:
%   iML1515.mat
%
% % important variables:
%   max_num_interv - defines the maximum number of possible gene cuts and
%                    substrate additions
%
% % process:
%   0) Start parallel pool to speed up FVAs
%   1) Setup model, add heterologous  reactions
%   2) Define Target and Desired regions for MCS computation
%   3) Run MCS computation
%   4) Validate MCS
%   5) Characterize and Rank results
%
% Correspondence: cellnetanalyzer@mpi-magdeburg.mpg.de
% -Mar 2020
%

%% 0) Starting CNA and Parallel pool (for faster FVA), defining compression setting
if ~exist('cnan','var')
    startcna(1)
end
% Add helper functions to matlab path
function_path = [fileparts(mfilename('fullpath') ) '/../functions'];
addpath(function_path);

max_solutions   = inf;
max_num_interv  = 6;
options.milp_solver     = 'matlab_cplex'; % 'java_cplex'; 
options.milp_split_level             = true;
options.milp_reduce_constraints      = true;
options.milp_combined_z              = true;
options.milp_irrev_geq               = true;
options.preproc_D_violations         = 0;
options.pre_GPR_network_compression  = false;
options.compression_GPR              = true;
options.preproc_compression          = true;
% If runnning on SLURM. Use directory on internal memory to share data 
% between the workers. If job is running as a SLURM ARRAY, the compression 
% switches are overwritten
if ~isempty(getenv('SLURM_JOB_ID')) && isempty(gcp('nocreate'))
    % start parpool and locate preferences-directory to tmp path
    prefdir = start_parallel_pool_on_SLURM_node();
    if ~isempty(getenv('SLURM_ARRAY_TASK_ID')) % overwrite options if a SLURM array is used
        [options,model] = derive_options_from_SLURM_array(str2double(getenv('SLURM_ARRAY_TASK_ID')));
    end
% If running on local machine, start parallel pool and keep compression
% flags as defined above.
elseif license('test','Distrib_Computing_Toolbox') && isempty(getCurrentTask()) && ...
       (~isempty(ver('parallel'))  || ~isempty(ver('distcomp'))) && isempty(gcp('nocreate'))
    parpool(); % remove this line if MATLAB Parallel Toolbox is not available
    wait(parfevalOnAll(@startcna,0,1)); % startcna on all workers
end
options.preproc_check_feas = false;
options.milp_time_limit    = inf;
options.mcs_search_mode    = 2; % bottom-up stepwise enumeration of MCS.
%% 1) Model setup
% load model
load('iML1515.mat')
cnap = block_non_standard_products(cnap);

% Add pathway from DOI 10.1186/s12934-018-1038-0 Erian, Pfluegl 2018
cnap = CNAaddSpeciesMFN(cnap,'actn_c',0,'Acetoin');
cnap = CNAaddSpeciesMFN(cnap,'23bdo_c',0,'3-Hydroxybutan-2-one');
cnap = CNAaddReactionMFN(cnap,'ACLDC','1 alac__S_c + 1 h_c = 1 co2_c + 1 actn_c' ,0,1000,0,nan,0,...
'//START_GENERIC_DATA{;:;deltaGR_0;#;num;#;NaN;:;uncertGR_0;#;num;#;NaN;:;geneProductAssociation;#;str;#;;:;}//END_GENERIC_DATA',0,0,0,0);
cnap = CNAaddReactionMFN(cnap,'BTDD','1 h_c + 1 nadh_c + 1 actn_c = 1 nad_c + 1 23bdo_c' ,0,1000,0,nan,0,...
'//START_GENERIC_DATA{;:;deltaGR_0;#;num;#;NaN;:;uncertGR_0;#;num;#;NaN;:;geneProductAssociation;#;str;#;;:;}//END_GENERIC_DATA',0,0,0,0);
cnap = CNAaddReactionMFN(cnap,'EX_23bdo_e','1 23bdo_c =' ,0,1000,0,nan,0,...
'//START_GENERIC_DATA{;:;deltaGR_0;#;num;#;NaN;:;uncertGR_0;#;num;#;NaN;:;geneProductAssociation;#;str;#;;:;}//END_GENERIC_DATA',0,0,0,0);

% add alternative substrate supplies
cnap.reacMin(ismember(cnap.reacID,{'EX_glc__D_e'})) = -10;
cnap = CNAaddReactionMFN(cnap,'EX_ac_up_e','1 ac_e =' ,-30,0,0,nan,0,...
'//START_GENERIC_DATA{;:;deltaGR_0;#;num;#;NaN;:;uncertGR_0;#;num;#;NaN;:;geneProductAssociation;#;str;#;;:;}//END_GENERIC_DATA',0,0,0,0);
cnap.reacMax(ismember(cnap.reacID,{'EX_glyc_e'})) = 0;
cnap.reacMin(ismember(cnap.reacID,{'EX_glyc_e'})) = -20;
% cnap.reacMin(ismember(cnap.reacID,{'NADH16pp'})) = -1000;

%% 2) Define MCS setup
% some reaction indices used in Target and Desired region
r23BDO_ex = find(strcmp(cellstr(cnap.reacID),'EX_23bdo_e'));
rGlc_up  = find(strcmp(cellstr(cnap.reacID),'EX_glc__D_e'));
rGlyc_up = find(strcmp(cellstr(cnap.reacID),'EX_glyc_e'));
rAc_up   = find(strcmp(cellstr(cnap.reacID),'EX_ac_up_e'));
rAc_ex   = find(strcmp(cellstr(cnap.reacID),'EX_ac_e'));
rATPM    = find(strcmp(cellstr(cnap.reacID),'ATPM'));
rBM      = find(~cellfun(@isempty,(regexp(cellstr(cnap.reacID),'BIOMASS_.*_core_.*'))));

% Target region - Yield is now referred to carbon uptake with 23bdo/glc as
% the reference. The strain design task is to enforce a yield of 30% compared
% to the maximum possible yield.
fixed_fluxes = nan(cnap.numr,1);
fixed_fluxes([rAc_up,rGlyc_up]) = 0;
Ymax_23bdo_per_glc = CNAoptimizeYield(cnap,full(sparse(1,r23BDO_ex,1,1,cnap.numr)),full(sparse(1,rGlc_up,-1,1,cnap.numr)),fixed_fluxes);
Ymax_c = Ymax_23bdo_per_glc/6*4; % carbon related Yield
Y_thresh = Ymax_c * 0.3; % 30 % of the maximum carbon yield
disp(['Minimum carbon product yield threshold set to ' num2str(Y_thresh)]);
% T1: Under all circumstances the 2,3 BDO / glc+glyc yiled should exceed
%     the yield threshold
T1 = full(sparse( [1         1          1          ], ...
                  [r23BDO_ex rGlc_up    rGlyc_up   ], ...
                  [4         6*Y_thresh	3*Y_thresh ],1,cnap.numr));
t1 =  0;
% T2: If Acetate is not secreted, the 2,3 BDO / glc+glyc+ac yiled should exceed
%     the yield threshold
T2 = full(sparse( [1         1          1           1           2       ], ...
                  [r23BDO_ex rGlc_up    rGlyc_up    rAc_up      rAc_ex  ], ...
                  [4         6*Y_thresh	3*Y_thresh	2*Y_thresh  1       ],2,cnap.numr));
t2 =  [  0 ; 0 ];

% Desired regions: 
% (1) Biomass production rate > 0.05 h^-1 if grown on glucose (or
%     equivalent when grown on other substrates)
% (2) ATPM >= 12 mM/gBDW/h
Y_BM = 0.005; % Minimum Biomass Yield (referred to glucose / 6C)
D1 = full(sparse( [1         1          1          1       ], ...
                  [rBM       rGlc_up    rGlyc_up   rAc_up  ], ...
                  [-6        -6*Y_BM    -3*Y_BM    -2*Y_BM ],1,cnap.numr));
d1 = 0;

T = {T1 T2};
t = {t1 t2};
D = {D1};
d = {d1};

% knockables: All reactions with gene rules + O2 exchange as a potential knockout
rkoCost = nan(cnap.numr,1);
rkoCost(strcmp(cellstr(cnap.reacID),'EX_o2_e')) = 0;
% pseudo-gene that marks spontanous reactions is not knockable
[~,~,genes,gpr_rules] = CNAgenerateGPRrules(cnap);
gkoCost = ones(length(genes),1);
gkoCost(ismember(genes,'spontanous')) = nan;

gkiCost = nan(length(genes),1);
% addibles: Glucose, glycerol or acetate supply
rkiCost = nan(cnap.numr,1);
rkiCost([rGlc_up rAc_up rGlyc_up]) = 0;

%% 3) MCS Computation
tic;
[rmcs, gmcs, gcnap, cmp_gmcs, cmp_gcnap, mcs_idx] = CNAgeneMCSEnumerator2(cnap, T, t, D, d,...
                                                    rkoCost,rkiCost, ... % reackoCost,reackiCost
                                                    max_solutions,max_num_interv, ...
                                                    gkoCost,gkiCost, ...  genekoCost, genekiCost
                                                    [],options,... gpr_rules,options
                                                    1); % verbose, debug

comp_time = toc;
disp(['Computation time: ' num2str(comp_time) ' s']);

%% 4) validate MCS
if full(~all(all(isnan(gmcs)))) % if mcs have been found
    disp('Verifying mcs');
	valid = verify_mcs(gcnap,gmcs,gcnap.mcs.T,gcnap.mcs.t,gcnap.mcs.D,gcnap.mcs.d);
else
    valid = [];
end
if ~isempty(getenv('SLURM_ARRAY_TASK_ID'))
    filename = ['des1tar2-' model '-' getenv('SLURM_JOB_ID')];
else
    filename = ['des1tar2-' model '-' datestr(date,'yyyy-mm-dd')];
end
save([filename '.mat'],'gcnap','gmcs','valid');

% remove this statement to characterize and rank the computed MCS
rmpath(function_path);
return

%% 5) Characterization and ranking of MCS
% Instead of the gene-MCS, their corresponding reaction-representations are analyzed.
% This is preferred, because the reaction-model is smaller and therefore analysis is 
% faster than in the GPR-extended model. Furthermore different gene-MCS can lead to 
% identical 'phenotypes' when translated to the reaction-model and by analyzing rMCS
% only a reduced, non-redundant set of reaction-MCS needs therefore to be considered.
if full(~all(all(isnan(gmcs)))) % if mcs have been found
    disp('Characterizing mcs');
  % 5.1) Lump redundant MCS and create flux bounds for each mutant model
    rmcs(isnan(rmcs)) = -inf; % this step allows to apply 'unique' too remove duplicates
    [rmcs,~,gmcs_rmcs_map] = unique(rmcs','rows');
    rmcs = rmcs';
    rmcs(rmcs == -inf) = nan;
    MCS_mut_lb = repmat({cnap.reacMin},1,size(rmcs,2));
    MCS_mut_ub = repmat({cnap.reacMax},1,size(rmcs,2));
    MCS_mut_lb = arrayfun(@(x) MCS_mut_lb{x}.*(rmcs(:,x)==1 | rmcs(:,x)==0),1:size(rmcs,2),'UniformOutput',0);
    MCS_mut_ub = arrayfun(@(x) MCS_mut_ub{x}.*(rmcs(:,x)==1 | rmcs(:,x)==0),1:size(rmcs,2),'UniformOutput',0);
  % 5.2) Set relevant indices [criterion 2-7] and prepare thermodynamic (MDF) parameters [criterion 9]
    % reaction indices
    [idx,mdfParam] = relev_indc_and_mdf_Param(cnap);
    idx.prod = r23BDO_ex;
    idx.prodYieldFactor = 4;
    idx.subs = [rGlc_up rGlyc_up rAc_up];
    idx.subsYieldFactor = [-6 -3 -2];
    idx.excluding_Up_Ex_reacs = [rAc_up rAc_ex];
    idx.bm      = rBM;
  % 5.3) Define core metabolism [criterion 8]
    % Add the new reactions also to the list of reactions that will be
    % considered "core" reactions in the final MCS characterization and ranking
    new_reacs = ismember(cellstr(cnap.reacID),{'ACLDC','BTDD','EX_23bdo_e','EX_glyc_up_e','EX_ac_up_e'});
    reac_in_core_metabolism(new_reacs) = 1;
    lbCore = cnap.reacMin;
    ubCore = cnap.reacMax;
    lbCore(~reac_in_core_metabolism) = 0;
    ubCore(~reac_in_core_metabolism) = 0;
  % 5.4) Costs for genetic interventions  [criterion 10]
    intvCost                  = gcnap.mcs.kiCost;
    intvCost(isnan(intvCost)) = gcnap.mcs.koCost(isnan(intvCost));
    intvCost(gcnap.rType == 'g') = 1;
    gene_and_reac_names = cellstr(gcnap.reacID);
    gene_and_reac_names(gcnap.rType == 'g') = genes; % to avoid the 'GR-' prefix
  % 5.5) Start characterization and ranking
    [MCS_rankingStruct, MCS_rankingTable]...
        = CNAcharacterizeGeneMCS( cnap , MCS_mut_lb, MCS_mut_ub, 1:size(MCS_mut_lb,2),... model, mutants LB,UB, incices ranked mcs
        idx, idx.cytMet, D, d, T, t, mdfParam, ... relevant indices, Desired and Target regions
        lbCore, ubCore, gmcs, intvCost, gene_and_reac_names, gmcs_rmcs_map, ...
        0:10, ones(1,10),2); % assessed criteria and weighting factors
end
% save ranking and textual gmcs as tab-separated-values
cell2csv([filename '.tsv'],MCS_rankingTable,char(9));
text_gmcs = cell(size(gmcs,2),1);
for i = 1:size(gmcs,2)
    kos = find(~isnan(gmcs(:,i)) & gmcs(:,i) ~= 0);
    for j = 1:length(kos)
        text_gmcs(i,j) = cellstr(gcnap.reacID(kos(j),:));
    end
end
cell2csv([filename '-gmcs.tsv'],text_gmcs,char(9));
save([filename '.mat'],'gmcs_rmcs_map','MCS_rankingStruct','MCS_rankingTable','cnap','rmcs','T','t','D','d','rkoCost','rkiCost','-append');

% clear irrelevant variables
a=[setdiff(who,{'cnap','rmcs','D','d','T','t','compression','filename','gcnap',...
                'gmcs','gmcs_rmcs_map','gpr_rules','rmcs','valid','comp_time'});{'a'}];
rmpath(function_path);
clear(a{:});

function [options,model] = derive_options_from_SLURM_array(numcode)
    settings = numcode;
    settings = arrayfun(@str2num,dec2bin(settings,10));
    options.milp_split_level             = settings(1);
    options.milp_reduce_constraints      = settings(2);
    options.milp_combined_z              = settings(3);
    options.milp_irrev_geq               = settings(4);
    if settings(5)
        options.preproc_D_violations     = 2;
    else
        options.preproc_D_violations     = 0;
    end
    options.pre_GPR_network_compression  = settings(6);
    options.compression_GPR              = settings(7);
    options.preproc_compression          = settings(8);
    if settings(9)
        model = 'iML1515';
    else
        model = 'ECC2';
    end
    if settings(10)
        options.milp_solver = 'matlab_cplex';
    else
        options.milp_solver = 'java_cplex';
    end
    disp(['Test ID: ' num2str(settings([1 2 3 4 5])) '-' num2str(settings([6 7 8]))]);
    disp(['split level: '    num2str(settings(1))]);
    disp(['reduce_constraints: ' num2str(settings(2))]);
    disp(['combined_z: '     num2str(settings(3))]);
    disp(['irrev_geq: '      num2str(settings(4))]);
    disp(['preproc_D_leth: ' num2str(settings(5))]);
    disp(['Net compress 1: ' num2str(settings(6))]);
    disp(['GPR compress: '   num2str(settings(7))]);
    disp(['Net compress 2: ' num2str(settings(8))]);
    disp(['Model: ' model]);
    disp(['Using CPLEX MATLAB (1) or JAVA (0) API: ' num2str(settings(10))]);
end
% This script compares our new CNAgeneMCSEnumerator2 with the existing gMCS 
% approach by Apaolaza et al. 2017 (https://doi.org/10.1038/s41467-017-00555-y) (and Apaolaza et al. 2019)
% by computing synthetic lethals up to the size of 4 gene deletions in the genome-scale
% E. coli model iML1515. The script returns the computation time and the 
% number of solutions for both cases.
%
% -Jun 2020
%

% start CNA
if ~exist('cnan','var')
    startcna(1)
end
% Add helper functions to matlab path
function_path1 = [fileparts(mfilename('fullpath') ) '/../functions'];
function_path2 = [fileparts(mfilename('fullpath') ) '/../e_coli'];
addpath(function_path1);
addpath(function_path2);

% start Cobra Toolbox
global CBTDIR
if isempty(CBTDIR)
    initCobraToolbox(0);
end
clear('CBTDIR');

% Start Parallel pool
if ~isempty(getenv('SLURM_JOB_ID')) && isempty(gcp('nocreate'))
    % start parpool and locate preferences-directory to tmp path
    prefdir = start_parallel_pool_on_SLURM_node();
% If running on local machine, start parallel pool and keep compression
% flags as defined above.
elseif license('test','Distrib_Computing_Toolbox') && isempty(getCurrentTask()) && ...
       (~isempty(ver('parallel'))  || ~isempty(ver('distcomp'))) && isempty(gcp('nocreate'))
    parpool(); % remove this line if MATLAB Parallel Toolbox is not available
    wait(parfevalOnAll(@startcna,0,1)); % startcna on all workers
end

load('iML1515.mat')

% remove bounds (bounds are neglected in the gMCS aproach)
cnap.reacMin(cnap.reacMin>=0) = 0;
cnap.reacMin(cnap.reacMin<0)  = -inf;
cnap.reacMax(cnap.reacMax<=0) =  0;
cnap.reacMax(cnap.reacMax>0) =  inf;

[~,~,~,gpr_Rules] = CNAgenerateGPRrules(cnap);
maxSize = 4;
% Compare results from gmcs (Apaolaza 2019) with the gene-extension MCS

%% geneMCSEnumerator2
idx_bm = find(cnap.objFunc);
T = {sparse(1,idx_bm,-1,1,cnap.numr)};
t = {-1e-3}; % this is the default threshold used by Apaolaza
maxSolutions = inf;
options.mcs_search_mode     = 2; % bottom-up stepwise enumeration of MCS.
options.preproc_check_feas  = false;
options.preproc_D_violations= 0;
options.postproc_verify_mcs = false;
options.milp_split_level=true;
options.milp_reduce_constraints=false;
options.milp_combined_z=false;
options.milp_irrev_geq=false;

tic;
[~, mcs2, gcnap, ~, ~, ~] = CNAgeneMCSEnumerator2(cnap,T,t,{},{},[],[],maxSolutions,maxSize,[],[],gpr_Rules,options,1);
time_new = toc;
disp(time_new);

%% gMCS / Apaolaza et al. 2019
model = CNAcna2cobra(cnap);
model.grRules = CNAgetGenericReactionData_as_array(cnap,'geneProductAssociation');

options.timelimit = inf;

model = generateRules(model,0);
model = buildRxnGeneMat(model);
global CBT_MILP_SOLVER;
CBT_MILP_SOLVER = 'ibm_cplex';
delete(['G_' getenv('SLURM_JOB_ID') '_.mat']);
tic;
[gmcs, gmcs_time] = calculateGeneMCS('', model, inf, maxSize, options);
time_apa = toc;
disp(time_apa);
delete(['G_' getenv('SLURM_JOB_ID') '_.mat']);

% Translate text-MCS into MCS matrix
gmcs = text2num_mcs(gmcs,gcnap);

%% validate and compare both MCS
[valid_mcs2,max_mue_mcs] = verify_lethals(gcnap,mcs2);
[valid_gmcs,max_mue_apa] = verify_lethals(gcnap,gmcs);

disp([{'MCS2'} {'gMCS'}; num2cell([time_new time_apa; length(valid_mcs2) length(valid_gmcs)])]);

[~,~,~,compare_mat] = compare_mcs_sets(mcs2,gmcs);
if all(sum(compare_mat,1) == 3) && all(sum(compare_mat,2) == 3)
    disp('The solutions found by both approaches are identical.')
else
    disp('The solutions found by both approaches are not identical.')
end
rmpath(function_path1);
rmpath(function_path2);

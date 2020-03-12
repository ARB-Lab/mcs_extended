MCS extended
============

An extended and generalized MCS framework

2020/03/11

Philipp Schneider, Axel von Kamp, Steffen Klamt

Added Features:
---------------

1.  Definition of multiple target regions (**T**·**r** ≤ **t**) and multiple desired
    regions (**D**·**r** ≤ **d**).

2.  Specification of **gene** and **reaction deletion** and **addition**
    candidates and **individual cost factors** for each intervention.

3.  Fast computation of **gene-based MCS** using **GPR associations** and novel
    **compression** techniques.

Software Requirements:
----------------------

1.  MATLAB 2016b® or later

2.  IBM ILOG® CPLEX® 12.7, 12.8, 12.9 or 12.10

3.  CellNetAnalyzer2020.1

4.  Set up *CellNetAnalyzer* for the access of the CPLEX-Matlab-API and
    CPLEX-Java-API (edit startcna.m and javalibrarypath.txt as described by
    *CellNetAnalyzer* manual)

Script Files:
-------------

1. **Cofeeding-example.m**

   Demonstrates how CNAMCSEnumerator2 can be used to compute strain designs
   for single subtrate feeding and substrate co-feeding from a single MCS setup.

2. **GPR-example.m** 

   Demonstrates how CNAgeneMCSEnumerator2 computes gene-based MCS using
   GPR associations and advanced compression routines.

3. **benchmark.m**

   Computes and characterizes gene-MCS for the production of 2,3-BDO in *E.coli* in
   a core (ECC2) and a genome-scale (iML1515) setup. The scipt benchmarks the runtime reduction 
   achieved through applying the novel GPR rule compression. The computed MCS for the genome-scale
   setup (scenario 1) also serve as a reference for scripts 4-6.
   Results are saved to a .mat file in the working directory and the MCS
   characterization/ranking is saved as a .tsv table. By changing the variables in
   the script to e.g. model='full' or compression=[0 0 1], different setups and
   compression routines can be used.

   model='ECC2': Computation from an E. coli core model with ca. 500 reactions
   model='full': Computation from a genome-scale E. coli model (iML1515) with ca. 2700 reactions
   compression=[0 0 0]: Computing MCS without using any compression techniques
   compression=[0 0 1]: Computing MCS using only network compression
   compression=[0 1 0]: Computing MCS using only GPR-rule compression
   compression=[0 1 1]: Computing MCS using first GPR-rule then network compression
   compression=[1 1 0]: Computing MCS compressing first the network, then the GPR-rules

4. **desired2.m**

   Computes and characterizes genome-scale gene-MCS for the production of
   2,3-BDO in E.coli from a similar setup as in scenario 1 (benchmark.m). A second
   desired region is added to the setup to ensure that strain designs support higher ATP
   maintanance rates. The results of scenario 2 are saved to a .mat file in the working directory and
   the MCS characterization/ranking is saved as a .tsv table.

5. **des1tar2.m**

   Computes and characterizes genome-scale gene-MCS for the production of
   2,3-BDO in E.coli. A second target region is added to scenario 1 to compute, at the same time, single substrate and co-feeding 
   strategies using glucose, acetate and glycerol. Therefore, the supply reactions for glucose, acetate and glycerol are specified as addition candidates. Results of scenario 3 are saved to a .mat file in the working directory and the MCS
   characterization/ranking is saved as a .tsv table.

6. **des2tar2.m**

   Computes and characterizes genome-scale gene-MCS for the production of
   2,3-BDO in E.coli. In addition to the changes in scenario 3, a second desired
   region is added to demand the support of higher ATP maintanance rates. This
   setup shows that a combination of multiple target and desired regions is
   possible and generates again qualitatively new solutions. Results of 
   scenario 4 are saved to a .mat file in the working directory and the MCS
   characterization/ranking is saved as a .tsv table.

New API functions:
-------------

7. **CNAgeneMCSEnumerator2**

   Function wrapper for CNAMCSEnumerator2 that allows the computation of
   gene-MCS using GPR association and GPR-rule compression, multiple target and desired regions and gene- and reaction
   deletions and additions with individual intervention cost factors.

8. **CNAMCSEnumerator2**

   MCS computation with multiple target and desired regions, reaction additions
   and deletions and individual cost factors.

9. **CNAgenerateGPRrules.m** 

   Translates GPR-rules provided in text form into a gene-protein-reaction
   mapping.

10. **CNAintegrateGPRrules.m**

    Extends a metabolic network model with genes and GPR rules represented by
    pseudoreaction and pseudometabolites. Uses mapping generated by
    CNAgenerateGPRrules.m

11. **CNAcharacterizeGeneMCS.m**

    Characterizes and ranks geneMCS by different criteria, such as product
    yield, ability to grow, implementation effort

Minor functions:
-------------
12. **testRegionFeas.m** 

    Tests if a model/mutant has feasible steady state flux vectors in a flux space spanned by a set of constraints (**V**·**r** ≤ **v**).

__Required for scripts:__

13. **verify_mcs.m** 

14. **cell2csv.m**

15. **relev_indc_and_mdf_Param.m**

16. **start_parallel_pool_on_SLURM_node.m**

17. **block_non_standard_products**

Model files:
-------------

18. **benchmark_iJOcore.mat** - E. coli core model required for script (3)

19. **iML1515.mat** - genome scale E. coli core model required for scripts (3-6)

Remarks:
--------

-   If a fast but incomplete iterative MCS computation/search is preferred over
    a full MCS enumeration, set the parameter "enum_method" (e.g. in scripts
    3-6) from 2 to 1 and set a time or solution limit.

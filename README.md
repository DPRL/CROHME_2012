
RIT DPRL CROHME 2012
---------------
DPRL CROHME 2012

Copyright (c) 2012-2014 Lei Hu, David Stalnaker, Richard Zanibbi

This file is part of DPRL CROHME 2012.

DPRL CROHME 2012 is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

DPRL CROHME 2012 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with DPRL CROHME 2012. If not, see <http://www.gnu.org/licenses/>.

Contact:
   - Lei Hu: lei.hu@rit.edu
   - David Stalnaker: david.stalnaker@gmail.com
   - Richard Zanibbi: rlaz@cs.rit.edu 
-----------------
This document is about DPRL's submission for the [CROHME 2012]. CROHME is the abbreviation of Competition on Recognition of Online Handwritten Mathematical Expression. 

The DPRL CROHME 2012 is a three-stage system comprised of a fuzzy segmenter, a Hidden Markov Model classifier, and a DRACULAE parser.

For the segmentation, strokes are pre-processed to detect some specific conditions to guide the subsequent merging. The merge membership values of the strokes are defined by comparing the stroke distances against predefined threshold values. All possible sequences of merge decisions are considered for sequences of strokes/segments where segmentation is not determined precisely. These (local) segmentationalternatives are scored by the product of merge and split (set to 1) membership. An upper bound of 10 adjacent strokes in one of these fuzzy regions is set to reduce combinations.

The HMM used for classification is similar to the paper [HMM-Based Recognition of Online Handwritten Mathematical Symbols Using Segmental K-means Initialization and a Modified Pen-up/down Feature], but with an additional angular feature. The details about preprocessing, feature selection and HMM algorithm can be found in the paper.

The classification confidence produced by HMM classifier is used to improve the segmentation. The final segmentation obtained by greedy selection of the highest probability for each local fuzzy segmentation. A second segmentation index is obtained using the sum of the top-1 HMM classification probability, and its division by the average probability produced for symbols of the correct class after training. This sum is associated with
each stroke belonging to a segment/symbol, and then added across strokes in a fuzzy segmentation. The final segmentation probability is defined using a histogram over the fuzzy and HMM-based scores, to estimate the highest probable valid segmentation.

Finally, a DRACULAE parser is used to produce the final parse result from symbols and their bounding boxes. Additional tree rewriting rules are added to correct common classification errors (e.g. recognizing 'log' as '10g'). More details about the parser can be found at [DRACULAE parser].

How to run the codes?
----
To execute our system for Part 1, issue: ./dprlPart3 inputfile.inkml outputfile.inkml

The system is trained on Part3 data of CROHME2012.

The input and output inkml file is in the format of CROHME and the description of the data file format can be found at [CROHME data format].

For debugging purposes, the intermediate files: temp.dat, DRACULAE.bst are currently not deleted from this directory during execution.

To avoid warning messages about limited available stackfrom the parser, as root (sudo) you can issue: sudo ulimit -s unlimited

Library CROHMELib and LgEval are needed. The details of CROHMElib and LgEval can be found in [CROHMELib and LgEval document]. 

[CROHME 2012]:http://ieeexplore.ieee.org/xpl/articleDetails.jsp?tp=&arnumber=6424497&queryText%3DCROHME+2012

[DRACULAE parser]:http://ieeexplore.ieee.org/xpls/abs_all.jsp?arnumber=1046157&tag=1

[HMM-Based Recognition of Online Handwritten Mathematical Symbols Using Segmental K-means Initialization and a Modified Pen-up/down Feature]:http://ieeexplore.ieee.org/xpl/articleDetails.jsp?tp=&arnumber=6065353&queryText%3D%5BHMM-Based+Recognition+of+Online+Handwritten+Mathematical+Symbols+Using+Segmental+K-means+Initialization+and+a+Modified+Pen-up%2Fdown+Feature%5D

[Segmenting Handwritten Math Symbols Using AdaBoost and Multi-Scale Shape Context Features]:http://ieeexplore.ieee.org/xpl/articleDetails.jsp?tp=&arnumber=6628800&queryText%3D%5BSegmenting+Handwritten+Math+Symbols+Using+AdaBoost+and+Multi-Scale+Shape+Context+Features%5D

 [A shape-based layout descriptor for classifying spatial relationships in handwritten math]:http://dl.acm.org/citation.cfm?id=2494315
 
 [CROHME data format]:http://www.isical.ac.in/~crohme/data2.html
 
 [label graph file format]:http://www.cs.rit.edu/~dprl/CROHMELib_LgEval_Doc.html
 
 [Evaluating structural pattern recognition for handwritten math via primitive label graphs]:http://www.cs.rit.edu/~dprl/Publications.html
 
 [CROHMELib and LgEval document]:http://www.cs.rit.edu/~dprl/CROHMELib_LgEval_Doc.html
 
 [DPRL_Math_Symbol_Recs]:http://www.cs.rit.edu/~dprl/Software.html


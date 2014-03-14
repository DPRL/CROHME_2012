%{
    DPRL CROHME 2012
    Copyright (c) 2012-2014 Lei Hu, David Stalnaker, Richard Zanibbi

    This file is part of DPRL CROHME 2012.

    DPRL CROHME 2012 is free software: 
    you can redistribute it and/or modify it under the terms of the GNU 
    General Public License as published by the Free Software Foundation, 
    either version 3 of the License, or (at your option) any later version.

    DPRL CROHME 2012 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with DPRL CROHME 2012.  
    If not, see <http://www.gnu.org/licenses/>.

    Contact:
        - Lei Hu: lei.hu@rit.edu
        - David Stalnaker: david.stalnaker@gmail.com
        - Richard Zanibbi: rlaz@cs.rit.edu 
%}

function [all_symbol_likelihood, all_symbol_class, all_symbol_segmentation_score] = symbol_recognition_segmentation(SymbolCandidateData, symbol_prior_probability, hmm_parameter, average_pro, BinInfo, stroke_num, AspectRatio)
%SymbolCandidateData is a cell
% the input is the name of input file, the output all_symbol_likelihood
% is a 1x56 array, stores the likelihood descendly of all symbol class.
% all_symbol_class is a struct, recording the corresponding symbol class
% name.

stroke_data = SymbolCandidateData;
symbol_feature_vector = extract_feature(stroke_data);

namelen = length(symbol_prior_probability) + 2;
LL = zeros(1,namelen-2);
real_LL = zeros(1,namelen-2);
sample_feature_vector = symbol_feature_vector';

 for inamelen =1:namelen-2 % calculate the likelihood of each class of sysbol
    
    LL(inamelen) = mhmm_logprob(sample_feature_vector,...
        hmm_parameter(inamelen).prior1, hmm_parameter(inamelen).transmat1,...
        hmm_parameter(inamelen).mu1, hmm_parameter(inamelen).Sigma1,...
        hmm_parameter(inamelen).mixmat1);
    
    if ~(isreal( LL(inamelen)))||isnan(LL(inamelen))
        real_LL(inamelen) = -inf;
    else real_LL(inamelen) =  LL(inamelen);
    end
    
 end

 % get the global feature probability
 GlobalPro = GetGlobalPro(BinInfo, stroke_num, AspectRatio);
 

% get the segmentation score
normal_pro = exp(real_LL).*GlobalPro;
segmentation_score = normal_pro./average_pro;
real_LL = exp(real_LL).*symbol_prior_probability.*GlobalPro;% with priors
%normalization
real_LL = real_LL/sum(real_LL);

[sorted_LL, sorted_index] = sort(real_LL,'descend');
 all_symbol_likelihood = sorted_LL;
 all_symbol_segmentation_score = segmentation_score(sorted_index);
 
 all_recognized_symbol_class = struct('symbol_class',{});% is a struct, to store all the symbol class
 for inamelen =1:namelen-2 
 all_recognized_symbol_class(inamelen).symbol_class = hmm_parameter(sorted_index(inamelen)).symbol_name;
 end
 
 all_symbol_class = all_recognized_symbol_class;

end
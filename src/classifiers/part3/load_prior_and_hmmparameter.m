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

function [Symbol_Prior_Probability, Hmm_Parameter] = load_prior_and_hmmparameter
% this function is used to load the 'symbol_prior.mat' and the hmm
% parameters for all the symbol classes

%load the 'symbol_prior'
symbol_prior = load('symbol_prior.mat');
symbol_prior_probability = [symbol_prior.symbol_prior.prior_probability];

%load the hmm parameters
cur_dir = pwd();
source_dir = strcat(cur_dir, '/parameter');
foldername = dir(source_dir);
folder_names = {foldername.name};
namelen = length(folder_names);

hmm_parameter = struct('symbol_name',{},'prior1',{}, 'transmat1',{},...
    'mu1',{}, 'Sigma1',{}, 'mixmat1',{});

for inamelen = 3:namelen
    
    load_data = load(strcat(source_dir,'/',folder_names{inamelen}));
    hmm_parameter(inamelen-2) =  load_data;
    
end

Symbol_Prior_Probability = symbol_prior_probability;
Hmm_Parameter = hmm_parameter;
end
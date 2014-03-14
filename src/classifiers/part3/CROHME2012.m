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

% this script is used produce the DRACULAE input
function CROHME2012(ExpressionName)


%% load the bin information
cur_dir = cd;
source_dir = strcat(cur_dir, '/Bin');
foldername = dir(source_dir);
folder_names = {foldername.name};
namelen = length(folder_names);

BinInfo = struct('BinLength',{},'BinPro',{});

for inamelen = 3:namelen
    folder_names{inamelen};
    load_data = load(strcat(source_dir,'/',folder_names{inamelen}));
    BinInfo(inamelen-2) =  load_data; 
end

%% load the symbol_prior_probability, hmm_parameter, and average_pro
[symbol_prior_probability, hmm_parameter] = load_prior_and_hmmparameter;
load_average_probability = load('average_probability.mat');
ap_and_si = load_average_probability.ap_and_si;

average_pro = zeros(1, length(ap_and_si));
for i=1:length(ap_and_si)
    average_pro(i) = ap_and_si{i}.ap;
end


%% get segmentation results using Dave's method and
%% Lei's greedy method
CurrentDir = cd;
DestinationDir = cd;

    ExpressionFolder = strcat(DestinationDir,'/', ExpressionName);

 SegmentationResults = GetSegmentationResults(ExpressionFolder, ExpressionName, symbol_prior_probability, hmm_parameter, average_pro, BinInfo);
     
     CSV = GetCSV(SegmentationResults, ExpressionFolder, ExpressionName, symbol_prior_probability, hmm_parameter, average_pro, BinInfo);
     
quit
end

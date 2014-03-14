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

% preprocessed_symbol_data is a struct, it contain the "num": the number of
% points, it is a int whose value is 30; "coordinate": the coordiantes of
% the 30 points, including the x,y coordinates and the pen-up/down
% information; "multi_str" : indicate the symbol is mutle-stroke or
% single-stroke.

function preprocessed_symbol_data = preprocessing_symbol_data(stroke_data)
average_num = 30;

preprocessed_symbol_data = equal_distance(stroke_data,average_num);
  
end


         
         
         
    
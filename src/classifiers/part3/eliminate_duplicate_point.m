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

%This function is used to eliminate the duplicate point, whick could not
%provide useful information.

function edp_symbol_data = eliminate_duplicate_point(stroke_data)

new_symbol_data = transform_symbol_data_format(stroke_data);
edp.num =  1;
edp.coordinate = new_symbol_data.coordinate(1,:);
edp.numinstroke = new_symbol_data.numinstroke;
edp.multi_str = new_symbol_data.multi_str;

for i = 2: new_symbol_data.num
    
    if  (new_symbol_data.coordinate(i-1,1) == new_symbol_data.coordinate(i,1) &...
            new_symbol_data.coordinate(i-1,2) == new_symbol_data.coordinate(i,2))
        edp.numinstroke(new_symbol_data.coordinate(i,3)) = edp.numinstroke(new_symbol_data.coordinate(i,3))-1;
    else
        edp.num = edp.num + 1;
        edp.coordinate = [edp.coordinate; new_symbol_data.coordinate(i,:)];
              
    end
    
    edp_symbol_data = edp;
    
end
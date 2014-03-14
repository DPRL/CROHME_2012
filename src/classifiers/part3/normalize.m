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

%This function is used to normalize the coordinates of the points. The
%function turns the absolute coordinate into the relative coordinate
%compared to the min_x and min_y. The range of new y coordinate is [0,1],
%and the range of new x coordinate is [0, delta_x/delta_y]. The
%origin of the new coordinate system is at the lower left quarter.

function normalized_symbol_data = normalize(stroke_data)

edp_symbol_data = eliminate_duplicate_point(stroke_data);
max_x = edp_symbol_data.coordinate(1,1);
min_x = edp_symbol_data.coordinate(1,1);
max_y = edp_symbol_data.coordinate(1,2);
min_y = edp_symbol_data.coordinate(1,2);

for i = 2: edp_symbol_data.num
    
    if edp_symbol_data.coordinate(i,1)>max_x
        max_x = edp_symbol_data.coordinate(i,1);
    end
    
    if edp_symbol_data.coordinate(i,1)<min_x
        min_x = edp_symbol_data.coordinate(i,1);
    end
    
    if edp_symbol_data.coordinate(i,2)>max_y
        max_y = edp_symbol_data.coordinate(i,2);
    end
    
    if edp_symbol_data.coordinate(i,2)<min_y
        min_y = edp_symbol_data.coordinate(i,2);
    end
    
end

delta_x = max_x - min_x;
delta_y = max_y - min_y;

if delta_y ~= 0
for j = 1: edp_symbol_data.num
    
        edp_symbol_data.coordinate(j,1) = abs(edp_symbol_data.coordinate(j,1) - min_x)/delta_y;
        edp_symbol_data.coordinate(j,2) = abs(edp_symbol_data.coordinate(j,2) - min_y)/delta_y;    
end
else 
    for j = 1: edp_symbol_data.num
        edp_symbol_data.coordinate(j,2) = 0.5;% a feature is normalized y position
    end
end

normalized_symbol_data = edp_symbol_data;

end
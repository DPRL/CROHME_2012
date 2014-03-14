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

function negative_sine_of_slope = negative_slope_sine(all_point_coordinate)
% the sign of the feature can denote writing up or down, positive for up
% and negative for down.
coordinates = all_point_coordinate;
co_length = size(coordinates,1);
NegativeSineofSlope = zeros(co_length,1);

for i = 3: co_length-2
    
    delta_x = coordinates(i+2,1)-coordinates(i-2,1);
    delta_y = coordinates(i+2,2)-coordinates(i-2,2);
    NegativeSineofSlope(i,1) = -sin(cart2pol(delta_x, delta_y));%add negative because the origin is at the top left
    
end

negative_sine_of_slope = NegativeSineofSlope;

end
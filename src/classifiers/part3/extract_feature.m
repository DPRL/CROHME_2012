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

function symbol_feature_vector = extract_feature(stroke_data)

 preprocessed_symbol_data = preprocessing_symbol_data(stroke_data);
 all_point_coordinate = preprocessed_symbol_data.coordinate;
 average_length = length(all_point_coordinate);
 symbol_feature_vector = zeros(average_length,4);
 
    symbol_feature_vector(:,1) = slope_cosine(all_point_coordinate);
    symbol_feature_vector(:,2) = normalized_y_position(all_point_coordinate);
    symbol_feature_vector(:,3) = penup_down(all_point_coordinate);
    symbol_feature_vector(:,4) = curvature_sine(all_point_coordinate);
    symbol_feature_vector(:,5) = negative_slope_sine(all_point_coordinate);
    
    [dim1, dim2] = size(symbol_feature_vector);
    
    for idim1 = 1:dim1
        
        for idim2 = 1:dim2
            
            if  ~isreal(symbol_feature_vector(idim1, idim2))||isnan(symbol_feature_vector(idim1, idim2))
                symbol_feature_vector(idim1, idim2) = 0;
                
            end
        end
        
    end
end

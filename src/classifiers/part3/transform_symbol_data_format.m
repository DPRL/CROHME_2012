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

%This function is used to transform the data format of symbol. In the new
%data format, it contains the number of total points of the symbol, the number of point in each stroke
%and the coordinate of every point. In the coordinate of every point, the third
%dimension denotes the order of stroke the point belongs to. It is used to
%discriminate the points interpolated which belongs to the invisible
%stroke. The multi_str denotes the symbol is multi-stroke symbol or not. If
%it is 1, then the symbol is multi-stroke symbol; if it is 0, then the
%symbol is single-stroke symbol.

function new_symbol_data = transform_symbol_data_format(stroke_data)

   cd = stroke_data;
    new_symbol_data_format.num = 0;
    new_symbol_data_format.coordinate = [];
    new_symbol_data_format.numinstroke = [];
    new_symbol_data_format.multi_str = 0 ;
    
    if length(cd)>1
        
        new_symbol_data_format.multi_str = 1;
        
    end
    
    for  k = 1:length(cd)
       
        new_symbol_data_format.num =  new_symbol_data_format.num + cd{k}.num;
        new_symbol_data_format.numinstroke = [new_symbol_data_format.numinstroke, cd{k}.num];
        for kn = 1:cd{k}.num
            
        new_symbol_data_format.coordinate = [new_symbol_data_format.coordinate; cd{k}.index(kn, :) k];
        
        end
        
    end
    
    new_symbol_data = new_symbol_data_format;
    
end
    
    
    
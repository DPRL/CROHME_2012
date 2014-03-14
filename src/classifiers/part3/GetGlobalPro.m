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

function GlobalPro = GetGlobalPro(BinInfo, stroke_num, AspectRatio)
% this function is used to get probability given the global feautre: stroke
% number and aspect ratio
SymbolClassNum = length(BinInfo);
GlobalProbability = zeros(1, SymbolClassNum);

for i = 1:SymbolClassNum
    BinLength = BinInfo(i).BinLength;
    BinPro = BinInfo(i).BinPro;
    
    if (stroke_num>4)
        ColumnIndex = 4;
    else
        ColumnIndex = stroke_num;
    end
    
    RowIndex = ceil(AspectRatio/BinLength);
    if (RowIndex == 0)
        RowIndex = 1;
    end
    
    if (RowIndex > 10)
        RowIndex = 10;
    end
    
    GlobalProbability(1,i) =  BinPro(RowIndex, ColumnIndex);
    
end

GlobalPro = GlobalProbability;

end
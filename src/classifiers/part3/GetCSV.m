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

function CSV = GetCSV(SegmentationResults, ExpressionFolder, ExpressionName, symbol_prior_probability, hmm_parameter, average_pro, BinInfo)

% this function is used to get the input CSV of DRACULAE

% get the segmentation information
ExpressionName = SegmentationResults.expression;
LeiSegmentationResult = SegmentationResults.LeiResult;

%% get the stroke index for each symbol
SemicolonLocation = strfind(LeiSegmentationResult,';');
SymbolNum = length(SemicolonLocation);

StrokeIndex = {};

if (SymbolNum == 1)% the expression just contains one symbol
    %get the stroke index for the only one symbol
    SpaceLocation = strfind(LeiSegmentationResult(1:SemicolonLocation(1)),' ');
    StrokeNum = length(SpaceLocation);
    CommaLocation = strfind(LeiSegmentationResult(1:SemicolonLocation(1)), ',');
    CommaNum = length(CommaLocation);
    
    StrokeIndex{1} = [];
    if (StrokeNum==1)
        StrokeIndex{1} = [StrokeIndex{1} str2num(LeiSegmentationResult(SpaceLocation(1)+1:SemicolonLocation(1)-1))];
    else
        for k = 1:StrokeNum-1
            StrokeIndex{1} = [StrokeIndex{1} str2num(LeiSegmentationResult(SpaceLocation(k)+1:CommaLocation(k)-1))];
        end
        StrokeIndex{1} = [StrokeIndex{1} str2num(LeiSegmentationResult(SpaceLocation(StrokeNum)+1:SemicolonLocation(1)-1))];
    end
else % the expression just contains more than one symbol
    PreviousStrokeNum = 0;
    %%get the stroke index for the 1st symbol
    SpaceLocation = strfind(LeiSegmentationResult(1:SemicolonLocation(1)), ' ');
    StrokeNum = length(SpaceLocation);
    CommaLocation = strfind(LeiSegmentationResult(1:SemicolonLocation(1)), ',');
    CommaNum = length(CommaLocation);
    
    StrokeIndex{1} = [];
    if (StrokeNum==1)
        StrokeIndex{1} = [StrokeIndex{1} str2num(LeiSegmentationResult(SpaceLocation(1)+1:SemicolonLocation(1)-1))];
    else
        for k = 1:StrokeNum-1
            StrokeIndex{1} = [StrokeIndex{1} str2num(LeiSegmentationResult(SpaceLocation(k)+1:CommaLocation(k)-1))];
        end
        StrokeIndex{1} = [StrokeIndex{1} str2num(LeiSegmentationResult(SpaceLocation(StrokeNum)+1:SemicolonLocation(1)-1))];
    end
    PreviousStrokeNum = PreviousStrokeNum + StrokeNum;
    
    %%get the stroke index for the other symbols
    for j = 2:SymbolNum
        SymbolString = LeiSegmentationResult(SemicolonLocation(j-1):SemicolonLocation(j));
        SpaceLocation = strfind(SymbolString, ' ');
        StrokeNum = length(SpaceLocation);
        CommaLocation = strfind(SymbolString, ',');
        CommaNum = length(CommaLocation);
        
        StrokeIndex{j} = [];
        
        if (StrokeNum==1)
            StrokeIndex{j} = [StrokeIndex{j} str2num(SymbolString(SpaceLocation(1)+1:length(SymbolString)-1))];
        else
            for k = 1:StrokeNum-1
                StrokeIndex{j} = [StrokeIndex{j} str2num(SymbolString(SpaceLocation(k)+1:CommaLocation(k)-1))];
            end
            StrokeIndex{j} = [StrokeIndex{j} str2num(SymbolString(SpaceLocation(StrokeNum)+1:length(SymbolString)-1))];
        end
        
        PreviousStrokeNum = PreviousStrokeNum + StrokeNum;
    end
end

%% get the symbol and bounding box information
SymbolLabel = {};
BoundingBox = zeros(SymbolNum,4);

for i = 1:SymbolNum
    
    StrokeIndexOneSymbol = StrokeIndex{i};
    SymbolData = GetSymbolData(ExpressionFolder, StrokeIndexOneSymbol);
    
    % !!!!!!!!!!!!!!!!!!!!!!!!!!!!!! the number of strokes
    stroke_num = length(SymbolData);
    
    % get the point data
    PointData = [];
    for n = 1:length(SymbolData)
        PointData = [PointData; SymbolData{n}.index];
    end
    
    %% get the aspect ratio
    AspectRatio = 0;
    
    % get the bounding box information
    MinX = min(PointData(:,1));
    MinY = min(PointData(:,2));
    MaxX = max(PointData(:,1));
    MaxY = max(PointData(:,2));
    BoundingBox(i,:) = [MinX MinY MaxX MaxY];
    
    DeltaX = MaxX - MinX;
    DeltaY = MaxY - MinY;
    
    if (DeltaY~=0)
        AspectRatio = DeltaX/DeltaY;
    end   
    
    OnlyOnePoint = 1;
    if size(PointData,1)==1
        OnlyOnePoint = 1;
    else
        TotalPointNum = size(PointData,1);
        for q = 2:TotalPointNum
            if (isequal(PointData(1,:), PointData(q,:))==0)% the coordinates of the two points are different
                OnlyOnePoint = 0;
                break;
            end
        end
    end
    
    if (OnlyOnePoint==0)
        [all_symbol_likelihood, all_symbol_class, all_symbol_segmentation_score] = symbol_recognition_segmentation(SymbolData, symbol_prior_probability, hmm_parameter, average_pro, BinInfo, stroke_num, AspectRatio);
        SymbolLabel{i} = all_symbol_class(1).symbol_class;
    else
        SymbolLabel{i} = 'dot';
    end
    
    
end

%% to convert the negative data to positive in bounding box
minX = min(BoundingBox(:,1));
minY = min(BoundingBox(:,2));

if minX<0
    BoundingBox(:,1) = BoundingBox(:,1) + abs(minX);
    BoundingBox(:,3) = BoundingBox(:,3) + abs(minX);
end

if minY<0
    BoundingBox(:,2) = BoundingBox(:,2) + abs(minY);
    BoundingBox(:,4) = BoundingBox(:,4) + abs(minY);
end


%% get CSV
CSV.StrokeIndex = StrokeIndex;
CSV.BoundingBox = BoundingBox;
CSV.SymbolLabel = SymbolLabel;

%% write CSV
filename = strcat(ExpressionName,'.csv');
fidw = fopen(filename,'w');
for i = 1:SymbolNum
    %write the symbol label and bounding box
    fprintf(fidw, '%s%s%f%s%f%s%f%s%f%s', CSV.SymbolLabel{i},',',BoundingBox(i,1),',',BoundingBox(i,2),',',BoundingBox(i,3),',',BoundingBox(i,4),',');
    StrokeNum = length(CSV.StrokeIndex{i});
    if (StrokeNum==1)
        fprintf(fidw, '%d',CSV.StrokeIndex{i});
    else
        for j = 1:StrokeNum-1
            fprintf(fidw, '%d%s',CSV.StrokeIndex{i}(j),',');
        end
        fprintf(fidw, '%d',CSV.StrokeIndex{i}(StrokeNum));
    end
    fprintf(fidw,'\r\n');
end
fclose(fidw);
end
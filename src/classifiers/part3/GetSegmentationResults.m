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

function [SegmentationResults] = GetSegmentationResults(ExpressionFolder, ExpressionName, symbol_prior_probability, hmm_parameter, average_pro, BinInfo)
% this function is used to get Dave's and Lei's segmentation score at local uncertain part for an expression
InputFileName = strcat(ExpressionFolder,'/',ExpressionName,'.seg');
[UncertainAndCertainLocal, GroundTruth] = GetUncertainAndCertainLocalandGroundTruth(InputFileName);
% compared to GroundTruth, NewGroundTruth has a space ' ' before '0', and
% ';' after the index of the last stroke
NewGroundTruth = horzcat(' ', GroundTruth);
ColonLocation = strfind(NewGroundTruth,':');
NewGroundTruth = strcat(NewGroundTruth(1:ColonLocation-2), ';', NewGroundTruth(ColonLocation-1:length(GroundTruth)+1));

% get the intial segmentation results
SegmentationResults = {};
SegmentationResults.expression = ExpressionName;
SegmentationResults.groundtruth = NewGroundTruth;
SegmentationResults.DaveIsRight = 0;
SegmentationResults.LeiIsRight = 0;
SegmentationResults.DaveResult = '';
SegmentationResults.LeiResult = '';

LocalNum = length(UncertainAndCertainLocal);

if LocalNum > 0
    for i = 1:LocalNum
        StrokeIndex = UncertainAndCertainLocal{i}.StrokeIndex;%get the stroke index for uncertain local part
        StrokeNum = length(StrokeIndex);
        % get the description of the possiblesegmentation, including the
        % segmentaion and corresponding Dave's segmentation score, in a string
        % format
        PossibleSegmentationString = UncertainAndCertainLocal{i}.segmentation;
        [PossibleSegmentationNum, StringLength] = size(PossibleSegmentationString);
        
        if (PossibleSegmentationNum==1)% the part is certain
            
            LocalPartResult = PossibleSegmentationString;
            ColonLocation = strfind(LocalPartResult, ':');
            LocalPartResult = LocalPartResult(1:ColonLocation(1)-1);
            LocalPartResult(1) = ' ';
            LocalPartResult = strcat(LocalPartResult, ';');
            SegmentationResults.DaveResult = strcat(SegmentationResults.DaveResult, LocalPartResult);
            SegmentationResults.LeiResult = strcat(SegmentationResults.LeiResult, LocalPartResult);
            
            
        else % the part is uncertain
            
            DaveSegmentationScore = zeros(PossibleSegmentationNum,1);
            LeiSegmentationScore = zeros(PossibleSegmentationNum,1);
            FinalSegmentationScore = zeros(PossibleSegmentationNum,1);% it is the product of two above segmentation scores
                    
            for j = 1:PossibleSegmentationNum

                PossibleSegmentation = ones(StrokeNum,2);
                PossibleSegmentation(:,1) =  StrokeIndex';
                           
                %% get Dave's Segmentation Score
                ColonLocation = strfind(PossibleSegmentationString(j,:),':');
                DaveSegmentationScore(j,1) = str2double(PossibleSegmentationString(j,ColonLocation+2:StringLength));
                
                %% get possible symbol candidate
                SpaceLocation = strfind(PossibleSegmentationString(j,:),' ');
                SemicolonLocation = strfind(PossibleSegmentationString(j,:),';');
                if (~isempty(SemicolonLocation))
                    % all the strokes in the local part form more than one symbol
                    % if they just form one symbol, we don't have to do anything to the
                    % PossibleSegmentation
                    StrokeNumIn1stSymbol = length(strfind(PossibleSegmentationString(j,1:SemicolonLocation(1)),' '))+1;
                    PreviousStrokeNum = StrokeNumIn1stSymbol;
                    if(length(SemicolonLocation)==1)%all the strokes in the local part form two symbols
                        for k = StrokeNumIn1stSymbol+1:StrokeNum
                            PossibleSegmentation(k,2) = 2;
                        end
                    else%all the strokes in the local part form more than two symbols
                        % get the 2nd symbol to the 2nd last symbol
                        for k = 2:length(SemicolonLocation)
                            StrokeNumInCurrentSymbol = length(strfind(PossibleSegmentationString(j,SemicolonLocation(k-1):SemicolonLocation(k)),' '));
                            for l=1:StrokeNumInCurrentSymbol
                                PossibleSegmentation(PreviousStrokeNum+l,2) = k;
                            end
                            PreviousStrokeNum = PreviousStrokeNum + StrokeNumInCurrentSymbol;
                        end
                        % get the last symbol
                        for m = PreviousStrokeNum + 1:StrokeNum
                            PossibleSegmentation(m,2) = length(SemicolonLocation)+1;
                        end
                        
                    end
                end
                
                %% get Lei's Segmentation Score
                
                % add code here to filter those segmentations put more than four strokes as a symbol
                SymbolNum = PossibleSegmentation(StrokeNum,2); % the number of symbols in the segmentation
                
                % for each symbol, get the symbol level Lei's segmentation
                % score and assign the score to each stroke
                for k = 1:SymbolNum
                    StrokeIndexOneSymbol = [];
                    
                    for l = 1:StrokeNum
                        if (PossibleSegmentation(l,2)==k)
                            StrokeIndexOneSymbol = [StrokeIndexOneSymbol, PossibleSegmentation(l,1)];
                        end
                    end
                  
                    
                    %ExpressionFolder
                    SymbolData = GetSymbolData(ExpressionFolder, StrokeIndexOneSymbol);
                    % !!!!!!!!!!!!!!!!!!!!!!!!!!!!!! the number of strokes
                    stroke_num = length(SymbolData);
                    
                    % the symbol classifier will assume the symbol at least
                    % has two different points, if the data just contains
                    % one point, don't use them
                    % beginning of detect one point symbol
                    PointData = [];
                    for n = 1:length(SymbolData)
                        PointData = [PointData; SymbolData{n}.index];
                    end
                    
                    %% get the aspect ratio
                    AspectRatio = 0;
                    Coordinates = PointData;
                    
                    MaxX = max(Coordinates(:,1));
                    MinX = min(Coordinates(:,1));
                    MaxY = max(Coordinates(:,2));
                    MinY = min(Coordinates(:,2));
                    
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
                    
                    % end of detect one point symbol
                    if (OnlyOnePoint==0)
                        [all_symbol_likelihood, all_symbol_class, all_symbol_segmentation_score] = symbol_recognition_segmentation(SymbolData, symbol_prior_probability, hmm_parameter, average_pro, BinInfo, stroke_num, AspectRatio);
                        %% symbol classification probability is used to get
                        %% the segemenation score.
                        %% ATTENTION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        %% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        LeiSegmentationScore(j) = LeiSegmentationScore(j) + all_symbol_likelihood(1)*all_symbol_segmentation_score(1)*length(StrokeIndexOneSymbol);% get Lei's segmentation score at uncertain local part level
                    end
                    
                end
                
                
                %% get the final segmentation score
                FinalSegmentationScore(j) = LeiSegmentationScore(j)*DaveSegmentationScore(j);
            end
            
            [MaxFinalSegmentationScore, MaxFinalIndex] = max(FinalSegmentationScore);
            [MaxDaveSegmentationScore, MaxDaveIndex] = max(DaveSegmentationScore);
            
            DaveLocalPartResult = PossibleSegmentationString(MaxDaveIndex,:);
            ColonLocation = strfind(DaveLocalPartResult, ':');
            DaveLocalPartResult = DaveLocalPartResult(1:ColonLocation(1)-1);
            DaveLocalPartResult(1) = ' ';
            DaveLocalPartResult = strcat(DaveLocalPartResult, ';');
            SegmentationResults.DaveResult = strcat(SegmentationResults.DaveResult, DaveLocalPartResult);
            
            LeiLocalPartResult = PossibleSegmentationString(MaxFinalIndex,:);
            ColonLocation = strfind(LeiLocalPartResult, ':');
            LeiLocalPartResult = LeiLocalPartResult(1:ColonLocation(1)-1);
            LeiLocalPartResult(1) = ' ';
            LeiLocalPartResult = strcat(LeiLocalPartResult, ';');
            SegmentationResults.LeiResult = strcat(SegmentationResults.LeiResult, LeiLocalPartResult);
            
        end
    end
    % judge Dave's or Lei's segmentation is right or not
    if (~isempty(strfind(NewGroundTruth, SegmentationResults.DaveResult)))
        SegmentationResults.DaveIsRight = 1;
    end
    
    if (~isempty(strfind(NewGroundTruth, SegmentationResults.LeiResult)))
        SegmentationResults.LeiIsRight = 1;
    end
        
else

    SegmentationResults = {};
end
end


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

% this script is used to solve uncertain local part

clc, clear all, close all;

[UncertainLocal, GroundTruth] = GetUncertainLocalandGroundTruth('test.seg');

UncertainLocalNum = length(UncertainLocal);

for i = 1:UncertainLocalNum
    StrokeIndex = UncertainLocal{i}.StrokeIndex;%get the stroke index for uncertain local part
    StrokeNum = length(StrokeIndex);
    % get the description of the possiblesegmentation, including the
    % segmentaion and corresponding Dave's segmentation score, in a string
    % format
    PossibleSegmentationString = UncertainLocal{i}.segmentation;
    [PossibleSegmentationNum, StringLength] = size(PossibleSegmentationString);
    
    DaveSegmentationScore = zeros(PossibleSegmentationNum,1);
    LeiSegmentationScore = zeros(PossibleSegmentationNum,1);
    FinalSegmentationScore = zeros(PossibleSegmentationNum,1);% it is the product of two above segmentation scores
    
    AllPossibleSegmentation = zeros(StrokeNum, 2, PossibleSegmentationNum);
    
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
        AllPossibleSegmentation(:,:,j) = PossibleSegmentation;
        
        %% get Lei's Segmentation Score
        
        % add code here to filter those segmentations put more than four strokes as a symbol
        SymbolNum = AllPossibleSegmentation(StrokeNum,2,j); % the number of symbols in the segmentation
       % StrokeLeiSegmentationScore = zeros(StrokeNum,1);
        
        for k = 1:SymbolNum
            StrokeIndexOneSymbol = [];
            
            for l = 1:StrokeNum
                if (PossibleSegmentation(l,2)==k)
                    StrokeIndexOneSymbol = [StrokeIndexOneSymbol, PossibleSegmentation(l,1)];
                end
            end
            
            SymbolData = GetSymbolData('formulaire001-equation000', StrokeIndexOneSymbol);
            [all_symbol_likelihood, all_symbol_class, all_symbol_segmentation_score] = symbol_recognition_segmentation(SymbolData);
            
            LeiSegmentationScore(j) = LeiSegmentationScore(j) + all_symbol_segmentation_score(1)*length(StrokeIndexOneSymbol);
            
        end
        
        %% get the final segmentation score
        FinalSegmentationScore(j) = LeiSegmentationScore(j)*DaveSegmentationScore(j);
    end
    
    [MaxFinalSegmentationScore, MaxFinalIndex] = max(FinalSegmentationScore);
    
    
    AllPossibleSegmentation(:,:,MaxFinalIndex)
    
end
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

% this function is used to get uncertain and certain local segmentation,
% and ground truth

function [UncertainAndCertainLocal, GroundTruth] = GetUncertainAndCertainLocalandGroundTruth(SegmentationFile)
% SegmentationFile is the segmentation file name
fid = fopen(SegmentationFile);
tline = fgetl(fid);
LocalPartNum = 0;
UncertainAndCertainLocal = {};

while(tline~=-1)
    line1 = fgetl(fid);
    line2 = fgetl(fid);
    if(isempty(line2))% the segmentation is certain
        LocalPartNum = LocalPartNum + 1;
        strokes = [];
        StrokeLine = tline;
        
        
        CommaLocation = strfind(StrokeLine,',');
        if (length(CommaLocation)>0)% at least contains two strokes
            % get the stroke index in one certain part
            strokes = [strokes, str2num(tline(1:CommaLocation(1)-1))];
            if (length(CommaLocation)>1)%at least contains three strokes
                for i = 2:length(CommaLocation)
                    strokes = [strokes, str2num(tline(CommaLocation(i-1)+1:CommaLocation(i)-1))];
                end
            end
            strokes = [strokes, str2num(tline(CommaLocation(length(CommaLocation))+1:length(tline)))];
            
        else
            strokes = [strokes, str2num(tline)];
        end
        
        UncertainAndCertainLocal{LocalPartNum}.StrokeIndex = strokes;
        UncertainAndCertainLocal{LocalPartNum}.segmentation = line1;
        tline = fgetl(fid);
        
    else % the segmentation is uncertain
        LocalPartNum = LocalPartNum + 1;
        strokes = [];
        StrokeLine = tline;
        CommaLocation = strfind(StrokeLine,',');
        
        % get the stroke index in one uncerta
        strokes = [strokes, str2num(tline(1:CommaLocation(1)-1))];
        if (length(CommaLocation)>1)
            for i = 2:length(CommaLocation)
                strokes = [strokes, str2num(tline(CommaLocation(i-1)+1:CommaLocation(i)-1))];
            end
        end
        strokes = [strokes, str2num(tline(CommaLocation(length(CommaLocation))+1:length(tline)))];
        UncertainAndCertainLocal{LocalPartNum}.StrokeIndex = strokes;

        UncertainAndCertainLocal{LocalPartNum}.segmentation = line1;
        UncertainAndCertainLocal{LocalPartNum}.segmentation = [UncertainAndCertainLocal{LocalPartNum}.segmentation; line2];
        tline = fgetl(fid);
        % get the rest segmentation, when the while loop ends, it gets a
        % blank line
        while(~isempty(tline))
            UncertainAndCertainLocal{LocalPartNum}.segmentation = [UncertainAndCertainLocal{LocalPartNum}.segmentation; tline];
            tline = fgetl(fid);
        end
        
        tline = fgetl(fid);% get the new local part
    end
end

tline = fgetl(fid);
GroundTruth = tline;

fclose(fid);
end
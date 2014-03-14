#    DPRL CROHME 2012
#    Copyright (c) 2012-2014 Lei Hu, David Stalnaker, Richard Zanibbi
#
#    This file is part of DPRL CROHME 2012.
#
#    DPRL CROHME 2012 is free software: 
#    you can redistribute it and/or modify it under the terms of the GNU 
#    General Public License as published by the Free Software Foundation, 
#    either version 3 of the License, or (at your option) any later version.
#
#    DPRL CROHME 2012 is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with DPRL CROHME 2012.  
#    If not, see <http://www.gnu.org/licenses/>.
#
#    Contact:
#        - Lei Hu: lei.hu@rit.edu
#        - David Stalnaker: david.stalnaker@gmail.com
#        - Richard Zanibbi: rlaz@cs.rit.edu 

#!/bin/sh

INPUTFILELIST=$1

if [ -z $1 ]
then
	echo "usage: CROHME2012Lei.sh INPUTFILELIST"
	exit 1
fi

if [ ! -e $INPUTFILELIST ]
then
	echo "Input file list $INPUTFILELIST does not exist."
	exit 1
fi

COUNT=0
while read line

do  echo $line
    COUNT=$(($COUNT+1))
    INPUTFILE=$line
    #echo "INPUTFILE=$INPUTFILE"
    OUTPUTFILE="result.$INPUTFILE"
    #echo "OUTPUTFILE=$OUTPUTFILE"
./dprlPart3 $INPUTFILE $OUTPUTFILE
done <$INPUTFILELIST

echo "The value of \"COUNT\" is $COUNT."






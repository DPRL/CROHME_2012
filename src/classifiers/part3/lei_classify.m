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

function lei_classify(in_stroke_data, out_results, priors, hmm_params)

	fprintf(1, '***lei_classify START***\n');
	fprintf(1, in_stroke_data);
	fprintf(1, '\n');
	
	[probs,classes] = symbol_recognition(in_stroke_data, priors, hmm_params);
	file = fopen(out_results, 'w');
	for i=1:56,
		fprintf(file, classes(i).symbol_class);
		fprintf(file, ',');
		fprintf(file, '%e', probs(i));
		fprintf(file, '\n');
	end
	fclose(file);
	
	fprintf(1, out_results);
	fprintf(1, '\n');
	fprintf(1, '***lei_classify DONE***\n');

end

#! /usr/bin/perl
use XML::LibXML;
use Data::Dumper;
use strict;  

if($#ARGV == -1){
print "usage: 
	evalInkml.pl fileReference.inkml fileToTest.inkml [-W] [-V] [-R] [-C] [-M]
		to compare two files
OR	evalInkml.pl -L listOfCouples.txt [-W] [-V] [-R] [-C] [-M]
		to use a list couples of files and accumulate comparisons
		the list file contains one couple per line, the two file names split by a comma: 
		----- example of file list ---
		fileRef1.inkml, fileTest1.inkml
		../dir/fileRef2.inkml, ../dir2/fileTest2.inkml
		../dir/fileRef2.inkml, fileTest2b.inkml
		-------
OR	evalInkml.pl filecheck.inkml
		to check file format
Options : 
	-W : no warning on unmatched UI and MathML format
	-V : Verbose. Shows results for each file of list, and total in plain text
	-R : shows recognition rates instead of error rates
	-C : shows rates class by class
	-M : shows class confusion matrix for stroke and symbol recognition and MathML matching
Version : 1.6
Author: Harold Mouchère (LUNAM/University of Nantes/IRCCyN/IVC)
Apr 2012
";
exit();
}
### check options ####
my $list = 0;
my $warning = 1;
my $verbose  = 0;
my $byClass  = 0;
my $confMat = 0;
my $affRate = "err";
my $affExactMatch = "exactMatch";
foreach my $arg (@ARGV){
	if($arg =~ /-L/){
		$list = 1;
	}
	if($arg =~ /-W/){
		$warning  = 0;
	}
	if($arg =~ /-V/){
		$verbose  = "verb";
	}
	if($arg =~ /-R/){
		$affRate  = "reco";
	}
	if($arg =~ /-C/){
		$byClass  = 1;
	}
	if($arg =~ /-M/){
		$confMat  = 1;
	}

}
#define the global parser and its options (uses 'recover' because some xml:id do not respect NCName)
my $parser = XML::LibXML->new();
$parser->set_options({no_network=>1,recover=>2,validation=>0, suppress_warnings=>1,suppress_errors=>1});

my $errors = {};
my $stat = {};

if($#ARGV == 0){
	my $t1 = &Load_From_INKML($ARGV[0]);
	&check_mathMLNorm($t1->{XML_GT});
	exit(0);
}

if($list){ ### LIST MODE ####
	my $refFile;
	my $testFile;
	open(COUPLELIST,"<",$ARGV[1]);
	while(<COUPLELIST>){
		chomp;
		if(/\s*(\S.*\S)\s*,\s*(\S.*\S)/){
			$refFile = $1;
			$testFile = $2;
			my $t1 = &Load_From_INKML($refFile);
			my $t2 = &Load_From_INKML($testFile);
			if($warning){
				&check_mathMLNorm($t2->{XML_GT});
			}
			my $locErrors = {};
			my $locStat = {};
			&addInkStat($stat,$t1);#acumulate
			if(not $t1->{UI} eq $t2->{UI}){
				if($warning){
					print $testFile ." : UI warning : ".$t1->{UI} . " <> " . $t2->{UI} ."\n";
				}
				$t2 = &newTruthStruct();
			}
			&addErrors($locErrors, &Compare_strk_labels($t1,$t2));
			&addErrors($locErrors, &Compare_symbols($t1,$t2));
			
			&addErrors($locErrors, &exactGTmatch($t1->{XML_GT}, $t2->{XML_GT}));
			&addErrors($errors,$locErrors); #acumulate
			if($verbose){
				&addInkStat($locStat,$t1);
				print $testFile ." :\t";
				&showErrors($locErrors,$locStat,$affRate,$affExactMatch);
			}
		}
	}
}else{ ### 2 FILES MODE #####
	my $t1 = &Load_From_INKML($ARGV[0]);
	my $t2 = &Load_From_INKML($ARGV[1]);
	if($warning){
		&check_mathMLNorm($t2->{XML_GT});
	}
	if(not $t1->{UI} eq $t2->{UI}){
		if($warning){
			print "  UI warning : ".$t1->{UI} . " <> " . $t2->{UI} ."\n";
		}
		$t2 = &newTruthStruct();
	}	#print Dumper($t2);
	&addInkStat($stat,$t1);
	&addErrors($errors, &Compare_strk_labels($t1,$t2));
	&addErrors($errors, &Compare_symbols($t1,$t2));
	&addErrors($errors, &exactGTmatch($t1->{XML_GT}, $t2->{XML_GT}));
	#print "REF:[".ref($errors->{seg}->{"text"})."]\n";
}

### show results ####
	#print "All errors : \n".Dumper($errors);
unless($stat->{GT}){
	$affExactMatch = "";
}
&showErrors($errors,$stat,$verbose,$affRate,$affExactMatch);
if($byClass){
	print "\n";
	&showClassErrors($errors,$stat,$affRate);
}
if($confMat){
	print "\n";
	&showClassErrorsMatrix($errors,$stat);
}

exit();

########## SUB definitions ###########

## create the truth structure ###
sub newTruthStruct {
        my $self  = {};
        $self->{UI}   = "";
        $self->{STRK} = {};
        $self->{SYMB} = {};
        $self->{NBSYMB} = 0;
        $self->{XML_GT} = [];
        bless($self);           
        return $self;
}
############################
#### Load struct from an inkml file         ####
#### param : xml file name                    ####
#### out : truth struct                          ####
############################
sub Load_From_INKML {
	my $fileName = @_[0];
	my $truth = &newTruthStruct();
	if ( not ((-e $fileName) && (-r $fileName) ))
	{
		warn ("[$fileName] : file not found or not readable !\n"); 
		return $truth;
	} 
	if(-z $fileName){
		warn ("[$fileName] : empty file !\n"); 
		return $truth;
	}
	my $doc  = $parser->parse_file($fileName);
	my $ink;
	unless(defined eval {$ink = $doc->documentElement()}){
		warn ("[$fileName] : no xml !\n"); 
		return $truth;
	}
	my $xc = XML::LibXML::XPathContext->new( $doc );
	$xc->registerNs('ns', 'http://www.w3.org/2003/InkML');
	#print Dumper($data); 
	my @xmlAnn = $xc->findnodes('/ns:ink/ns:annotationXML');
	if($#xmlAnn > -1){ # there are at least one xml annotation
		if($#xmlAnn > 0 and $warning){
			print $fileName.": several annotationXML ($#xmlAnn) in this file, last is kept\n";
		}
		
		#print "Ann XML : ".Dumper($xmlAnn[0]); 
		&Load_xml_truth($truth->{XML_GT}, $xmlAnn[$#xmlAnn]->firstNonBlankChild);
		#print "XML : ".Dumper($truth->{XML_GT}); 
	}
	my $seg;
	my @groups = $xc->findnodes('/ns:ink/ns:traceGroup');
	if($#groups > 0 and $warning){
			print $fileName.": several segmentations ($#groups traceGroup) in this file, last is kept\n";
		}
	$seg = $groups[$#groups];
	
	$truth->{UI} = $xc->findvalue("/ns:ink/ns:annotation[\@type='UI']");
	#print "  UI = ".$truth->{UI}."\n";
	#print "\n";
	my $symbID = 0; #symbol ID, to distinguish the different symb with same label, if symbol without any annotationXML
	
	foreach my $group ($xc->findnodes('ns:traceGroup',$seg)){
		my $lab;
		my $id = $symbID;
		#print "SEG : ";
		$lab = ($group->getElementsByTagName('annotation')) [0]->textContent;
		my @annXml = $group->getElementsByTagName('annotationXML');
		if($#annXml > -1){
			$id = $annXml[0]->getAttribute('href');
			if($#annXml > 0 and $warning){
				print $fileName.": several xml href in one symbol ($#annXml), first is kept ($id)\n";
			}
		}
		#print $lab." : ";
		my @strList = (); #list of strokes in the symbol
		foreach my $stroke ($xc->findnodes('ns:traceView/@traceDataRef',$group)){
			#print $stroke->textContent." ";
			$truth->{STRK}->{$stroke->textContent} = { id => $id, lab => $lab};
			push @strList, $stroke->textContent;
		}
		#foreach $e (@strList){print $e." ";}print "<<<<\n";
		$truth->{SYMB}->{$id} = {lab => $lab, strokes =>[@strList]};
		#next symb
		$symbID++;
	}
	$truth->{NBSYMB} = $symbID;
	#print Dumper($truth);
	return $truth;
}

#############################################
#### Load xml truth from raw data, fill the current xml truth struct	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#### param 2 :  reference to current xml XML::LibXML::Node     	####
#############################################
sub Load_xml_truth {
	my $truth = @_[0];
	my $data = @_[1];
	my $current = {};
	# init current node
	$current->{name} = $data->nodeName;
	$current->{sub} = [];
	$current->{id} = undef;
	push @{$truth}, $current;
	#look for id 
	foreach my $attr ($data->attributes){
		if($attr->nodeName eq 'xml:id'){
			$current->{id} = $attr->nodeValue;
		}
	}
	# look for label and children
	foreach my $subExp ($data->nonBlankChildNodes()){
		if($subExp->nodeType == XML::LibXML::XML_TEXT_NODE){
			#if( =~ /(\S*)/){# non white character
				$current->{lab} = $subExp->nodeValue;
			#}
		}else{
			&Load_xml_truth($current->{sub}, $subExp);
		}	
	}
}

#############################################
#### Use xml truth struct to check CROHME normalization rules	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#############################################
sub check_mathMLNorm {
	my %symbTags = ("mi",1, "mo",1, "mn", 1);
	my %subExpNames = ("msqrt", 1,"msub",2,"msup",2, "mfrac",2, "msubsup",3,"munderover",3,"munder",2); 
	my $current = @_[0];
	foreach my $exp (@{$current}){
		#print "-$exp->{name}-:\n";
		#print $symbTags{"mi"};
		#print $subExpNames{"msup"};
		if($exp->{name} eq 'math'){
			#start
		}elsif($exp->{name} eq 'mrow'){
			# rule 1 :  no more than 2 symbols in a mrow
			if(@{$exp->{sub}} != 2){
				print("mrow problem deteted : not 2 children, nb=".@{$exp->{sub}}."\n");
			}else{
			#rule 2 : use right recursive for mrow , so left child should NOT be mrow
				if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
					print("mrow problem deteted : left child is mrow\n");
				}
			}
		}elsif($symbTags{$exp->{name}} == 1){
			#no sub exp in symbols
			if(@{$exp->{sub}} != 0){
				print($exp->{name}." problem deteted : at least one child, nb=".@{$exp->{sub}}."\n");
			}
			# we need a label 
			if($exp->{lab} eq ""){
				print($exp->{name}." problem deteted : no label\n");
			}
		}elsif($subExpNames{$exp->{name}} == 1){#test basic spatial relations
			#no more than 2 children
			if(@{$exp->{sub}} > 2){
				print($exp->{name}." problem deteted : more than 2 children, nb=".@{$exp->{sub}}."\n");
			}elsif(@{$exp->{sub}} == 2 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
				# if 2 children with 1 mrow, the mrow should be on right
				print($exp->{name}." problem deteted : left child is mrow in a ".$exp->{name}."\n");
			}elsif(@{$exp->{sub}} == 1 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
				print($exp->{name}." problem deteted : if only one child it should not be a mrow\n");
			}elsif(@{$exp->{sub}} == 0){
				print($exp->{name}." problem deteted : no child !\n");
			}
		}elsif($subExpNames{$exp->{name}} > 1){
			# for special relations with multi sub exp, we should have the exact number of children
			if(@{$exp->{sub}} > $subExpNames{$exp->{name}}){
				print($exp->{name}." problem deteted : more than ".$subExpNames{$exp->{name}}." children, nb=".@{$exp->{sub}}."\n");
			}
		}else{
			# reject other tags
			print "unknown tag :". $exp->{name}."\n";
		}
		#recursivity : process sub exp
		foreach my $subExp ($exp->{sub}){
			&check_mathMLNorm($subExp);
		}
	}
}
#############################################
#### Compare label of strokes               		####
#### param 1 :  reference truth struct   		####
#### param 2 :  evalated truth struct     		####
#### out : number of errors  of type {strkLab} detailed for each label	####
#############################################

sub Compare_strk_labels {
	my $gdTruth = @_[0];
	my $evTruth = @_[1];
	my $errors = {};
	my $evLab;
	my $strk;
	my $tr;
	
	#print ref($gdTruth->{STRK});
	while (($strk => $tr) = each(%{$gdTruth->{STRK}})){
		$evLab = $evTruth->{STRK}->{$strk}->{lab};
		if((not defined ($evLab)) or ($evLab eq "")){
			$evLab = "unknown";
		}
		if(not ($evLab eq $tr->{lab})){ #test if labels are equal
			#print " ++ :".$errors->{strkLab}->{$tr->{lab}}->{$evLab} . " -> ";
			$errors->{strkLab}->{$tr->{lab}}->{$evLab}++;
			#print $errors->{strkLab}->{$tr->{lab}}->{$evLab};
		}
		#print "\n";
	}
	#print "Compare_strk_labels output : " . Dumper($errors);
	return $errors;
}

#######################################################
#### Compare segmentation and label of symbols 			####
#### param 1 :  reference truth struct   			####
#### param 2 :  evalated truth struct     			####
#### out : 4 types of errors   (seg, segStrk, reco, recoStrk) detailed for each label 	####
#######################################################

sub Compare_symbols {
	my $gdTruth = @_[0];
	my $evTruth = @_[1];
	my $errors = {};
	my $symb;
	my $nbs;
	
	foreach $symb (values(%{$gdTruth->{SYMB}})){
		#find the symb ID in evTruth (use the first stroke)
		my $evSymbID = $evTruth->{STRK}->{$symb->{strokes}[0]}->{id};
		# compute diff of stroke sets
		my $diff = &setDiff($symb->{strokes}, $evTruth->{SYMB}->{$evSymbID}->{strokes});
		my $evLab = $evTruth->{SYMB}->{$evSymbID}->{lab};
		if((not defined ($evLab)) or ($evLab eq "")){
			$evLab = "unknown";
		}
		if(defined $diff and @{$diff} > 0){ # if segmentation error
				$errors->{seg}->{$symb->{lab}}->{$evLab}++;
				$nbs = @{$symb->{strokes}};
				$errors->{segStrk}->{$symb->{lab}}->{$evLab} += $nbs;
		}else{
			if(not ($evLab eq $symb->{lab})){ #test if labels are equal
				#print $evTruth->{SYMB}->{$evSymbID}->{lab}." =!= ". $symb->{lab}."(s".$symb->{strokes}[0].")\n";
				$errors->{reco}->{$symb->{lab}}->{$evLab}++;
				$nbs = @{$symb->{strokes}};
				$errors->{recoStrk}->{$symb->{lab}}->{$evLab}+= $nbs;
			}
		}
	}
	return $errors;
}

#######################################################
#### Add errors of different results respecting the error type		####
#### param 1 :  cumuled errors   				####
#### param 2 :  new errors to add     			####
#######################################################
sub addErrors {
	my ($cumulErr, $err) = @_;
	#print "ADD : \n".Dumper($err);
	foreach my $errType (keys (%{$err})){
		#print "ref : $errType [" . ref({$cumulErr->{$errType}})."]\n";
		foreach my $label (keys (%{$err->{$errType}})){
			#print "ref : $label [" . ref($err->{$errType}->{$label})."]\n";
			if(ref($err->{$errType}->{$label}) eq "HASH"){ #if it is an error matrix
				#print "foreach : ".$err->{$errType}->{$label}."\n";
				foreach my $labelConf (keys (%{$err->{$errType}->{$label}})){
					#print "cumul $labelConf : ".ref({$cumulErr->{$errType}->{$label}->{$labelConf}})."=".$err->{$errType}->{$label}->{$labelConf}."\n";
					$cumulErr->{$errType}->{$label}->{$labelConf} += $err->{$errType}->{$label}->{$labelConf};
				}
			}else{
				#print "not HASH\n";
				${$cumulErr->{$errType}->{$label}} += ${$err->{$errType}->{$label}};
			}
		}
	}
}


#######################################################
#### count each spatial relation (mathML tag) 			####
#### param 1 :  cumuled stats   				####
#### param 2 :  sub part of MathML tree     			####
#######################################################
sub addInkStatSpatRel {
	my ($stat, $truth) = @_;
	my $nbs;
	my $subExp;
	foreach $subExp (@{$truth}){
		$stat->{SPAREL}->{$subExp->{name}}++;#
		&addInkStatSpatRel($stat, $subExp->{sub});
	}
} 

#######################################################
#### Add stat about number of symbols and strokes 			####
#### param 1 :  cumuled stats   				####
#### param 2 :  one truth	     			####
#######################################################
sub addInkStat {
	my ($stat, $truth) = @_;
	my $nbs;
	my $symbID;
	foreach $symbID (keys(%{$truth->{SYMB}})){
		$stat->{SYMB}->{$truth->{SYMB}->{$symbID}->{lab}}++; ## one more symb of this label
		$nbs = @{$truth->{SYMB}->{$symbID}->{strokes}};
		$stat->{STRK}->{$truth->{SYMB}->{$symbID}->{lab}}+=$nbs; ## more strokes of this label		
	}
	&addInkStatSpatRel($stat, $truth->{XML_GT});
	$stat->{GT}++;
} 

#######################################################
#### Print errors types		 		####
#### param 1 :  cumuled errors    				####
#### param 2 :  cumuled stats	     			####
#### param 3 : (optionnal) reco rate (if 'reco') or error rate (if 'err',default) 	####
#### param 4 :  (optionnal) verbose if 'verb'     			####
#### param 4 :  (optionnal) shows exact match rate  if 'exactMatch'     		####
#######################################################
sub showErrors {
	my $errors = @_[0];
	my $stats = @_[1];
	my $verb = 0;
	my $eMatch = 0;
	my $affErr = 1;
	my $separator = " \t";
	for(my $p = 2; $p <= $#_ ; $p++){
		if(@_[$p]=~/reco/){
			$affErr = 0;
		}
		if(@_[$p]=~/verb/){
			$verb = 1;
		}
		if(@_[$p]=~/exactMatch/){
			$eMatch = 1;
		}
	}
	my $numStrk =  &sumValues($stats->{STRK});
	my $numStrkError = &sumValues($errors->{strkLab});
	if($verb){
		 $separator = " %\n";
		if($affErr){
			print "$numStrkError errors on stroke labels on $numStrk strokes : ";
		}else{
			print "".($numStrk - $numStrkError) ." correct labels on $numStrk strokes : ";		
		}
	}
	if($affErr){
		printf "%5.2f", ((100.0*$numStrkError)/$numStrk);
	}else{
		printf "%5.2f",(100.0 - (100.0*$numStrkError)/$numStrk);
	}
	print  $separator;
	
	my $numSymb =  &sumValues($stats->{SYMB});
	my $numSymbErrorSeg = &sumValues($errors->{seg});
	my $numSymbErrorReco = &sumValues($errors->{reco});
	my $numGTErrorMatch = &sumValues($errors->{match});
	my $numGT = ($stats->{GT});
	if($verb){
		if($affErr){
			print "$numSymbErrorSeg errors of segmentation on $numSymb symbols: ";
		}else{
			print "".($numSymb - $numSymbErrorSeg)." correct segmentations on $numSymb symbols: ";
		}
	}
	if($affErr){
		printf "%5.2f", ((100.0*$numSymbErrorSeg)/$numSymb);
	}else{
		printf "%5.2f", 100 - ((100.0*$numSymbErrorSeg)/$numSymb); 
	}
	print $separator;
	
	if($numSymb-$numSymbErrorSeg > 0){
		if($verb){
			if($affErr){
				print "$numSymbErrorReco errors of reco on ".($numSymb-$numSymbErrorSeg)." right seg symbols: ";
			}else{
				print "".(($numSymb-$numSymbErrorSeg) - $numSymbErrorReco)." correct reco on ".($numSymb-$numSymbErrorSeg)." right seg symbols: ";			
			}
		}
		if($affErr){
			printf "%5.2f", ((100.0*$numSymbErrorReco)/($numSymb-$numSymbErrorSeg)); 
		}else{
			printf "%5.2f", (100 - (100.0*$numSymbErrorReco)/($numSymb-$numSymbErrorSeg)); 
		}
	}else{
		if($verb){
			print "error of reco is undefined, not enought right segmented symbols...";
		}else{
			printf "%5.2f", 0;
		}
	}
	print $separator;
	if($verb){
		if($affErr){
			print "$numGTErrorMatch match errors on $numGT ground-truths: ";
		}else{
			printf "%d exact matchs on %d ground-truths: ",($numGT-$numGTErrorMatch),$numGT; 
		}
	}
	if($affErr){
		printf "%5.2f", ((100.0*$numGTErrorMatch)/$numGT);
	}else{
		printf "%5.2f", 100 - ((100.0*$numGTErrorMatch)/$numGT); 
	}
	print "\n";
	if($verb){
		my $totME = 0;
		foreach my $nbMatchEr (sort keys(%{$errors->{match}})){
			unless ($nbMatchEr eq "structure"){
				$totME += ${$errors->{match}->{$nbMatchEr}};
				if($affErr){
					printf "   %d match error on $numGT ground-truths if $nbMatchEr label/tag error are allowed : %5.2f\n",($numGTErrorMatch-$totME), ((100.0*($numGTErrorMatch-$totME))/$numGT);
				}else{
					printf "   %d exact match on $numGT ground-truths if $nbMatchEr label/tag error are allowed : %5.2f\n",($numGT - $numGTErrorMatch+$totME), (100.0 - (100.0*($numGTErrorMatch-$totME))/$numGT);
				}
			}
		}
	}
	

}

#######################################################
#### Print errors types		 		####
#### param 1 :  cumuled matrix errors    			####
#### param 2 :  cumuled stats	     			####
#### param 3 : (optionnal) reco rate (if 'reco') or error rate (if 'err',default) 	####
#######################################################
sub showClassErrors {
	my $errors = @_[0];
	my $stats = @_[1];
	my $affErr = 1;
	my $lab;
	for(my $p = 2; $p <= $#_ ; $p++){
		if(@_[$p]=~/reco/){
			$affErr = 0;
		}
	}
	my $numStrk =  &sumValues($stats->{STRK});
	my $numSymb =  &sumValues($stats->{SYMB});
	print "$numSymb Symbols and $numStrk Strokes: ";
	if($affErr){
		print "ERROR RATES\n"
	}else{
		print "RECO RATES\n"	
	}
	print "class      (symb/strk):Strk reco|Symb seg | Symb reco\n";
	print "-----------------------------------------------------\n";	
	foreach $lab (keys(%{$stats->{SYMB}})){
		printf "%10.10s (%4d/%4d):",$lab,$stats->{SYMB}->{$lab},$stats->{STRK}->{$lab};
		if($affErr){
			printf "%8d |%8d | %8d\n",
				&sumValues($errors->{strkLab}->{$lab}),
				&sumValues($errors->{seg}->{$lab}),
				&sumValues($errors->{reco}->{$lab});
		}else{
			printf "%8d |%8d | %8d\n",
				$stats->{STRK}->{$lab}-&sumValues($errors->{strkLab}->{$lab}),
				$stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}),
				$stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab})-&sumValues($errors->{reco}->{$lab});		
		}
	}
	print "\nclass      ( %symb/ %strk):%Strk reco| %Symb seg| %Symb reco\n";
	print "--------------------------------------------------------\n";	
	foreach $lab (keys(%{$stats->{SYMB}})){
		printf "%10.10s (%6.2f/%6.2f):  ",$lab,100.0*$stats->{SYMB}->{$lab}/$numSymb,100.0*$stats->{STRK}->{$lab}/$numStrk;
		if($affErr){
			printf "%6.2f  |  %6.2f  |  %6.2f\n",
				100.0* &sumValues($errors->{strkLab}->{$lab})/$stats->{STRK}->{$lab},
				100.0* &sumValues($errors->{seg}->{$lab})/$stats->{SYMB}->{$lab},
				100.0* &sumValues($errors->{reco}->{$lab})/(($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))||1);
		}else{
			printf "%6.2f  |  %6.2f  |  %6.2f\n",
				100.0*($stats->{STRK}->{$lab}-&sumValues($errors->{strkLab}->{$lab}))/$stats->{STRK}->{$lab},
				100.0*($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))/$stats->{SYMB}->{$lab},
				100.0*(($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))-&sumValues($errors->{reco}->{$lab}))/(($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))||1);		
		}
	}


}

#######################################################
#### Print errors types		 		####
#### param 1 :  cumuled matrix errors    			####
#### param 2 :  cumuled stats	     			####
#######################################################
sub showClassErrorsMatrix {
	my $errors = @_[0];
	my $stats = @_[1];
	my $lab;
	print "Confusion Matrix at Stroke level : \n";
	print "class      (strk):";
	foreach $lab (keys(%{$stats->{SYMB}})){ printf "%8.8s |",$lab}
	print " unknown\n----------------------------";	
	foreach $lab (keys(%{$stats->{SYMB}})){printf "----------";}print"\n";
	foreach $lab (keys(%{$stats->{SYMB}})){
		printf "%10.10s (%4d):",$lab,$stats->{STRK}->{$lab};
		foreach my $labC (keys(%{$stats->{SYMB}})){
			if($lab eq $labC){
				printf "%8d |", (($lab,$stats->{STRK}->{$lab}) - &sumValues($errors->{strkLab}->{$lab}));
			}else{
				printf "%8d |", ($errors->{strkLab}->{$lab}->{$labC}||0);
			}
		}
		printf "%8d \n", ($errors->{strkLab}->{$lab}->{"unknown"}||0);
	}
	print "\nConfusion Matrix at Symbol level : \n";
	print "class      (symb):";
	foreach $lab (keys(%{$stats->{SYMB}})){ printf "%8.8s |",$lab}
	print " seg Err\n----------------------------";	
	foreach $lab (keys(%{$stats->{SYMB}})){printf "----------";}print"\n";
	foreach $lab (keys(%{$stats->{SYMB}})){
		printf "%10.10s (%4d):",$lab,$stats->{SYMB}->{$lab};
		foreach my $labC (keys(%{$stats->{SYMB}})){
			if($lab eq $labC){
				printf "%8d |", (($lab,$stats->{SYMB}->{$lab}) - &sumValues($errors->{reco}->{$lab})- &sumValues($errors->{seg}->{$lab}));
			}else{
				printf "%8d |", ($errors->{reco}->{$lab}->{$labC}||0);
			}
		}
		printf "%8d \n", &sumValues($errors->{seg}->{$lab});
	}
	print "\nConfusion Matrix of sptatial relation errors in expression matching : \n";
	print "class      (symb):";
	my @allKeys = keys(%{$stats->{SPAREL}});
	push(@allKeys,  keys(%{$errors->{matchSpatRel}}));
	my %tempHash = ();
	foreach $lab (keys(%{$errors->{matchSpatRel}})){
		push(@allKeys,  keys(%{$errors->{matchSpatRel}->{$lab}}));
	}
	@tempHash{@allKeys} = ();
	delete(%tempHash->{math});
	@allKeys = sort keys %tempHash;
	foreach $lab (@allKeys){ printf "%8.8s |",$lab}
	print "  Err\n----------------------------";	
	foreach $lab (@allKeys){printf "----------";}print"\n";
	foreach $lab (@allKeys){
		printf "%10.10s (%4d):",$lab,$stats->{SPAREL}->{$lab};
		foreach my $labC (@allKeys){
			if($lab eq $labC){
				printf "%8d |", (($lab,$stats->{SPAREL}->{$lab}) - &sumValues($errors->{matchSpatRel}->{$lab}));
			}else{
				printf "%8d |", ($errors->{matchSpatRel}->{$lab}->{$labC}||0);
			}
		}
		printf "%8d \n", &sumValues($errors->{matchSpatRel}->{$lab});
	}
}


#######################################################
#### Exact match of Ground Truth Graph (recursive)	 		####
#### param 1 :  ref graph				####
#### param 2 :  evaluated graph	     			####
#### return match errors (matchSize, matchLab, matchSpatRel, match)		####
#######################################################
sub exactGTmatch {

	my $errors = {};
	my $nbErrors = 0;
	$errors = &exactGTmatchRecursive( @_[0], @_[1], $errors, 1);
	if(exists($errors->{matchSize}) and keys %{$errors->{matchSize}} > 0){
			if(not exists $errors->{match}->{structure}){
				my $temp = 0;
				$errors->{match}->{structure} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{match}->{structure}} += 1;
	}else{
		if(exists($errors->{matchLab})){		
			$nbErrors += (keys %{$errors->{matchLab}});
		}
		if(exists($errors->{matchSpatRel})){		
			$nbErrors += (keys %{$errors->{matchSpatRel}});
		}
		if($nbErrors){
			if(not exists $errors->{match}->{$nbErrors}){
				my $temp = 0;
				$errors->{match}->{$nbErrors} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{match}->{$nbErrors}} += 1;
		}
	}
	#print " After rec = \n";	
	#print Dumper($errors);
	return $errors;
	}
#######################################################
#### Exact match of Ground Truth Graph (recursive)	 		####
#### param 1 :  ref graph				####
#### param 2 :  evaluated graph	     			####
#### param 3 :  current match error     			####
#### param 4 :  true if it is the root level      			####
#### return cumulative match error	(matchSize, matchLab, matchSpatRel, match)	####
#######################################################
sub exactGTmatchRecursive {
	my $refGT = @_[0];
	my $evalGT = @_[1];
	my $match = 0;
	my $errors = {};
	$errors = @_[2];
	my $root = @_[3];

	#print $sub." IN REF =>".Dumper(@{$refGT});
	#print $sub." IN EVAL =>".Dumper(@{$evalGT});
	my $n = @{$refGT}; # number of children in ref
	my $sub;
	my $res;
	
	if($n == @{$evalGT}){#  ompare number of children 
		$match = 1;
		for ($sub = 0; ($sub < $n); $sub++){ # for each child
			#print @{$refGT}[$sub]->{name} . " ? ". @{$evalGT}[$sub]->{name}." and " . @{$refGT}[$sub]->{lab}  . " ? ".  @{$evalGT}[$sub]->{lab}."\n";
			my $GTName = @{$refGT}[$sub]->{name};# node name test
			if(($GTName eq "mi") or ($GTName eq "mo") or ($GTName eq "mn")){#ignore this kind of error
				$match =  ((@{$evalGT}[$sub]->{name} eq "mi") or (@{$evalGT}[$sub]->{name} eq "mo") or (@{$evalGT}[$sub]->{name} eq "mn")); # node name test
			}else{
				$match =  ($GTName eq @{$evalGT}[$sub]->{name}); # node name test
			}
			unless($match){
				#print "	Add SR error\n";
				$errors->{matchSpatRel}->{@{$refGT}[$sub]->{name}}->{@{$evalGT}[$sub]->{name}} ++; #save node name error
			}
			$match =  (@{$refGT}[$sub]->{lab} eq @{$evalGT}[$sub]->{lab}); #label test
			unless($match){
				#print "	Add Lab error\n";
				$errors->{matchLab}->{@{$refGT}[$sub]->{lab}}->{@{$evalGT}[$sub]->{lab}} ++; #save node label error
			}

			#print "REC  : ";
			#print " left =>".Dumper(@{$refGT}[$sub]->{sub});
			#print " right =>".Dumper(@{$evalGT}[$sub]->{sub});
			
			$res = &exactGTmatchRecursive(@{$refGT}[$sub]->{sub}, @{$evalGT}[$sub]->{sub}, $errors,0);
			
			if(exists($errors->{matchSize}->{"catch"})){# wrong format error in a child
				while ((my $key, my $value) = each(%{$errors->{matchSize}->{"catch"}})){
					#print "	Add size error : $key => $value\n";
					$errors->{matchSize}->{@{$refGT}[$sub]->{name}}->{$key} += $value; #save node name error
				}
				delete($errors->{matchSize}->{"catch"});
			}
		}
	}else{
		 
		my $n2 = @{$evalGT};
		#print "n=$n ; n2=$n2 ; root=$root\n"; 
		
		if($root){
			$match = 0;
			$errors->{matchSize}->{"root"}->{"ChildrenSize:".$n."vs".$n2}++;
		}else{
			$errors->{matchSize}->{"catch"}->{"ChildrenSize:".$n."vs".$n2}++;# let the father memorise the error to know the node name
		}
	}
	#print " RES rec = \n";	
	#print Dumper($errors);
	return $errors;
}

######## Utility sub ##########


sub setDiff {
	my ($first, $second) = @_;
	my %count = ();
	my $res = (); 
	#print "--\n";
	foreach my $element (@$first, @$second) { if(defined $element and not $element eq "") {$count{$element}++ }}
	foreach my $element (keys %count) {
		#print $element.":".$count{$element}."\n" ;
		if($count{$element} < 2){
			push @$res, $element ;
		}
	}
	return $res;
}

sub sumValues {
	my $hash = @_[0];
	my $v = 0;
	my $e;
	#print "SumVal : " . Dumper($hash);
	if(defined($hash)){
		foreach $e (values(%{$hash})){
			#print ref($e). " ";
			if(ref($e) eq "HASH"){
				#print "SumVal REC : ";
				$v += &sumValues($e);
			}elsif(ref($e) eq "SCALAR"){
				#print "SumVal SCALAR : ";
				$v += $$e;
			}else{
				$v += $e;
			}
		}
	}
	#print " sum = ". $v."\n";
	return $v;
}

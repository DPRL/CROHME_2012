#!/usr/bin/perl -w

use strict;
use XML::LibXML;
use LWP::UserAgent;
use URI::Escape;
# RZ: Addition for segment data.
use Text::CSV;
use POSIX;

use Data::Dumper;
$Data::Dumper::Indent = 1;

# Constants
my $USAGE_MSG = "usage: parse.pl segments.csv input.inkml output.inkml [OPTIONS]\n\n"
		. "Options.\n"
		. "\t-h|-help\tDisplay this help message.\n"
		. "\t-c=[0-0.5]\tSet the DRACULAE centroid ratio.\n"
		. "\t-t=[0-0.5]\tSet the DRACULAE vertical region threshold ratio.\n"
		. "\t-v|-verbose\tVerbose output.\n";

my $PARSER_SCALE = 1;
my %ICDAR_CHAR_MAP;
my $VERBOSE = 0;
my $PRODUCE_DAT = 0;

# DRACULAE default layout model parameters for
# centroid and vertical threshold ratios (as percentage of bounding
# box height).
my $CRATIO = 0.25;
my $TRATIO = 0.16666667;

# Variables
my $parser;
my $xc;
my $filename;
my $outfilename;
my $segFile;

# BEGIN EXECUTION
if ( @ARGV < 3 ) {
	print STDERR $USAGE_MSG;
	exit( 1 );
} else {
	unlink("merged.csv");
	system('touch merged.csv');

	# options
	for ( my $i = 0; $i < scalar @ARGV; $i++ ) {
		if ( $ARGV[ $i ] =~ /^-[h|(help)]$/ ) {
			print $USAGE_MSG;
			exit( 0 );
		} elsif ( $ARGV[ $i ] =~ /^-[v|(verbose)]$/ ) {
			$VERBOSE = 1;
		} elsif ( $ARGV[ $i ] =~ /^-c=(.+)$/ ) {
			$CRATIO = $1;
		} elsif ( $ARGV[ $i ] =~ /^-t=(.+)$/ ) {
			$TRATIO = $1;
		}
	}

	# initialize and run
	$segFile = $ARGV[ 0 ];
	$filename = $ARGV[ 1 ];
	$outfilename = $ARGV[ 2 ];
	
	# remove extension
	my $fname = $filename;
	$fname =~ s/\.inkml$//;
	
	parserInit(); # filename must be set before parser initialization
	charMapInit();
	
	# get file tags to be used later
	my $fileui;
	
	foreach my $_node ( $xc->findnodes( '/ns:ink/ns:annotation' ) ) {
		if ( $_node->getAttribute( "type" ) eq "UI" ) {
			$fileui = $_node->textContent();
		}
	}
	
	print "File UI: $fileui\n" if ( $VERBOSE );
	
	# RZ: Keeping this in hope that it allows visualization of results.
	# get stroke data and turn it into XML segments
	my @segments;
	my @strokecoords;
	my @bbcoords;
	my @segmentsetids;
	my $segsetid = 0;
	my @resulttable;
	my @segsym;
	my @rawtracecontent;

	my @segdata;
	
	my @traces = $xc->findnodes( '/ns:ink/ns:trace' );	
	foreach ( @traces ) {
		my $traceid = $_->getAttribute( 'id' );
		my $tracecontent = $_->textContent();
		
		# trace content is enclosed by \n; get rid of them
		$tracecontent =~ s/^\s+//;
		chomp( $tracecontent );
	
		# keep the raw strings in addition to conversion
		$rawtracecontent[ $traceid ] = $tracecontent;
		$strokecoords[ $traceid ] = strokeToCoords( $tracecontent );
		#print $strokecoords[ $traceid ];
	}

	# MODIFICATION for data with floating-point coordinates
	# (which DRACULAE may not process properly)
	# determine parser scale ONLY
	#determineParserScale( \@strokecoords );

	#foreach ( @traces ) {
	#	my $traceid = $_->getAttribute( 'id' );		
	#	$segments[ $traceid ] = strokeToSegmentXml( $strokecoords[ $traceid ], $traceid );
	#	$segmentsetids[ $traceid ] = -1;
	#}

	# Open the segments file.
	my $csv = Text::CSV->new();
	open (CSV, "<", $segFile) or die $!;

	my @segstrokelists;

	my $i = -1;
	my $inkmlseg = "";
	my $datfile = "";
	while (<CSV>) {
		if ($csv->parse($_)) {
			$i++;  # Increment segment index.
			my @columns = $csv->fields();
			my @clist = ();

			# InkML segment group data.
			for ( my $j = 5; $j < scalar @columns; $j++ ) {
				push( @clist, $columns[$j] );
			}
			$segstrokelists[ $i ] = [ @clist ];

			# Get symbol id and bounding box.
			# REMOVE trailing decimal places; scale by 20.
			my $scale = 20;
			my $symbol = symbolConvert( $columns[0] );
			my $minX = $columns[1];
			$minX = floor((scalar $minX) * $scale + 0.5);
			my $minY = $columns[2];
			$minY = floor((scalar $minY) * $scale + 0.5);
			my $maxX = $columns[3];
			$maxX = floor((scalar $maxX) * $scale + 0.5);
			my $maxY = $columns[4];
			$maxY = floor((scalar $maxY) * $scale + 0.5);

			# Generate DRACULAE .dat file entry for symbol, and append.
			my $finalbb = "(" . $minX . "," . $minY . "),("
			  . $maxX . "," . $maxY . ")";
			$datfile .= ( $symbol . "     <" . $finalbb . "> FFES_id: $i\n" );


		} else {
			my $err = $csv->error_input;
			print "Failed to parse line: $err";
		}
	}
	close CSV;
	#for $i ( 0 .. $#segstrokelists ) {
	#	for my $j ( 0 .. $#{$segstrokelists[$i]} ) {
	#		print "elt $i $j is $segstrokelists[$i][$j]\n";
	#	}
	#}

	# Finish the inkML segmentation data.
	#$inkmlseg .= "\t</traceGroup>\n";
	#$inkmlseg .= "</ink>\n";

	# Finish the .dat file.
	# Add the number of symbols to the first line of the file (prepend)
	$datfile = "Number of Symbols: " . $i . "\n" . $datfile;

	## create a local copy
	print "    Creating temp.dat ...\n";
	open( FOUT, '>', "temp" . ".dat" );
	print FOUT $datfile;
	close( FOUT );


	# Run, translate DRACULAE output - produce necessary DRACULAE.bst file (-intDir ./).
	my $DRACULAEresult = `./GetTeX.x temp.dat - -intDir ./ -centroidRatio $CRATIO -thresholdRatio $TRATIO`;
	#print "DEBUG ------------------------------\n";
	#print $DRACULAEresult . "\n";
	#print "------------------------------------\n";
	if ( $DRACULAEresult eq "" ) {
		print "ERROR: DRACULAE parse failure.\n";
		exit 1;
	}
	my $parsedata = `./ICDAROutput.x DRACULAE.bst`;
	
	# Define final (possibly merged) segments.
	my $secondcsv = Text::CSV->new();
	open (CSV, "<", "merged.csv") or die $!;

	$i = -1;
	$inkmlseg = "";
	while (<CSV>) {
		if ($secondcsv->parse($_)) {
			$i++;
			my @columns = $secondcsv->fields();
			my $symbol = $columns[ 0 ];
			$symbol =~ s/^\s+//;
			$symbol =~ s/\s+$//;
			my $segid = $columns[ 1 ];
			$segid =~ s/^\s+//;
		
			# InkML segment group data.
			my @seglist = ();
			push(@seglist, $columns[ 1 ]);
			for ( my $j = 2; $j < scalar @columns; $j++ ) {
				push (@seglist, $columns[ $j ] );
			}
			#print "Segment merges:\n";
			#print "@seglist\n";

			# Associate strokes with the segment (taking merges into account)
			my @segstrokes = ();
			for ( my $j = 0 ; $j < scalar @seglist; $j++ ) {
				my $nextSegment = $seglist[$j];
				#print "NEXT: $nextSegment\n";
				my @thestrokes = $segstrokelists[ $nextSegment ];
				for my $k ( 0 .. $#{$segstrokelists[$nextSegment]} ) {
					#print( $segstrokelists[ $nextSegment ][ $k ] . "\n");
					push(@segstrokes, $segstrokelists[ $nextSegment ][ $k ] );
				}
			}
			#print "Updated segment stroke list:\n";
			#print "@segstrokes\n";


			# Generate inkml segment data.
			$inkmlseg .= "\t\t<traceGroup xml:id=\"tg_$segid\">\n"; # FFES_id, symbol id, etc.
			$inkmlseg .= "\t\t\t<annotation type=\"truth\">" . $symbol . "</annotation>\n";
			$inkmlseg .= "\t\t\t<annotationXML href=\"$segid\" />\n";

			for ( my $j = 0 ; $j < scalar @segstrokes; $j++ ) {
				$inkmlseg .= "\t\t\t<traceView traceDataRef=\"$segstrokes[ $j ]\" />\n";
			}
			$inkmlseg .= "\t\t</traceGroup>\n";
		} else {
			my $err = $secondcsv->error_input;
			print "Failed to parse line: $err";
		}
	}
	close CSV;
	
	# Finish the inkML segmentation data.
	$inkmlseg .= "\t</traceGroup>\n";
	$inkmlseg .= "</ink>\n";


	#######################################
	# PRODUCING OUTPUT .inkml FILE
	#######################################
	# Header data
	my $inkml .= "<ink xmlns=\"http://www.w3.org/2003/InkML\">\n";
	$inkml .= "<annotation type=\"UI\">$fileui</annotation>\n";

	# Wrap the parse output (MathML)
	$inkml .= "<annotationXML type=\"truth\" encoding=\"Presentation-MathML\">\n";
	$inkml .= "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n";
	
	foreach my $parsedataline ( split( /\n/, $parsedata ) ) {
		$inkml .= "$parsedataline\n";
	}
	$inkml .= "</math>\n";
	$inkml .= "</annotationXML>\n";	
	
	# Replace the trace (pen) data.
	for ( my $i = 0; $i < scalar @rawtracecontent; $i++ ) {
		$inkml .= "\t<trace id=\"$i\">" . $rawtracecontent[ $i ] . "</trace>\n";
	}

	# Add segmentation data, produced above.
	$inkml .= "\t<traceGroup xml:id=\"A\">\n";
	$inkml .= "    <annotation type=\"truth\">Segmentation</annotation>\n";

	$inkml .= $inkmlseg;
	
	print "    Printing results to $outfilename ...\n";
	open( FOUT, '>', $outfilename );
	print FOUT $inkml;
	close( FOUT );
}


### SUBROUTINES ###

#
# parserInit
#
# Initializes the parser and the XPathContext for the document.
#
# params:	n/a
#
# returns:	n/ae
#
sub parserInit {
	$parser = XML::LibXML->new();
	$parser->set_options( { no_network => 1,
		                recover => 2,
		                validation => 0,
		                suppress_warnings => 1,
		                suppress_errors => 1 } );
	my $doc = $parser->parse_file( $filename );
	my $ink = $doc->documentElement();
	$xc = XML::LibXML::XPathContext->new( $doc );
	$xc->registerNs( 'ns', 'http://www.w3.org/2003/InkML' );
}

#
# strokeToSegmentXml
#
# Takes raw stroke data from an inkml file and manipulates it to return a
# Segment XML element, e.g.
#  		 <Segment type="pen_stroke"
#                         instanceID="n"
#                         scale="1,1"
#                         translation="0,0"
#                         points="x1,y1|x2,y2|..." />
#
# params:	[0] the raw point data
#        	[1] the instance id
#
# returns:	Segment element as raw string
#
sub strokeToSegmentXml {
	my $cref = $_[ 0 ];
	my $instanceid = $_[ 1 ];
	my $ret = "<Segment type=\"pen_stroke\" instanceID=\"" . $instanceid
	          . "\" scale=\"1,1\" translation=\"0,0\" points=\"";
	
	# manipulate point data
	my @points;
	for ( my $i = 0; $i < @{ $cref }; $i++ ) {
		my $cpref = $cref->[ $i ];
		push( @points, $cpref->[ 0 ] . "," . $cpref->[ 1 ] );
	}
	
	$ret .= join( '|', @points );
	
	$ret .= "\" />";
	
	return $ret;
}

#
# strokeToCoords
#
# Converts raw InkML-style stroke data and creates data structures for the 
# coordinates.
#
# params:	[0] the raw point data
#
# returns:	reference to array of coordinate data
#
sub strokeToCoords {
	my @coords = ();
	my $rawstr = $_[ 0 ];
	my @points = split( /,/, $rawstr );
	map( $_ =~ s/^\s//, @points ); # no ws at beginning
	map( $_ =~ s/\s$//, @points ); # no ws at end
	foreach my $coord ( @points ) {
		my @xypair = split( /\s/, $coord );
		#print $xypair[ 0 ] . " " . $xypair[ 1 ] . "\n";
		push( @coords, [ $xypair[ 0 ], $xypair[ 1 ] ] );
	}
	# print Data::Dumper->Dump( \@coords );
	return \@coords;
}

#
# bbFromPoints
#
#
# Takes an array of pairs (array of two-element arrays) and iteratively finds
# the minimum and maximum (x,y) values for the top-left and bottoom-right
# (respectively) coordinates for the bounding-box for the points given.
#
# This subroutine will also handle scaling of coordinates. Presumably the
# scale factor has been set appropriately for the data by the time this is
# called.
#
# params:	[0] array of two-element arrays, the point data
#
# returns:	array ref:	[0] (x,y) for top-left of bounding box
#         	          	[1] (x,y) for bottom-right of bounding box
#
sub bbFromPoints {
	my @coords = @{ $_[ 0 ] };
	
	my $xmin = -1;
	my $xmax = -1;
	my $ymin = -1;
	my $ymax = -1;
	
	for ( my $i = 0; $i < scalar @coords; $i++ ) {
		my $x = $coords[ $i ][ 0 ];
		my $y = $coords[ $i ][ 1 ];
		$xmax = $x if ( $x > $xmax );
		$ymax = $y if ( $y > $ymax );
		$xmin = $x if ( $x < $xmin or $xmin == -1 );
		$ymin = $y if ( $y < $ymin or $ymin == -1 );		
	}

	# scale all coordinates
	$xmin = int( ( $xmin * $PARSER_SCALE ) + 0.5 );
	$ymin = int( ( $ymin * $PARSER_SCALE ) + 0.5 );
	$xmax = int( ( $xmax * $PARSER_SCALE ) + 0.5 );
	$ymax = int( ( $ymax * $PARSER_SCALE ) + 0.5 );
	
	return [ [ $xmin, $ymin ], [ $xmax, $ymax ] ];
}

#
# bbCombine
#
# Combines two bounding-boxes, returning the bounding-box containing both.
#
# params:	[0] reference to first bounding box
#        	[0] reference to second bounding box
#
# returns:	reference to new bounding box containing both inputs
#
sub bbCombine {
	my @bb1 = @{ $_[ 0 ] };
	my @bb2 = @{ $_[ 1 ] };
	
	return [ [ min( $bb1[ 0 ][ 0 ], $bb2[ 0 ][ 0 ] ),
		   min( $bb1[ 0 ][ 1 ], $bb2[ 0 ][ 1 ] ) ],
		 [ max( $bb1[ 1 ][ 0 ], $bb2[ 1 ][ 0 ] ),
		   max( $bb1[ 1 ][ 1 ], $bb2[ 1 ][ 1 ] ) ] ];
}

#
# min
#
# Returns the smaller of two numbers.
#
# params:	[0] n1
#        	[1] n2
#
# returns:	minimum( n1, n2 )
#
sub min {
	return $_[ 0 ] if ( $_[ 0 ] < $_[ 1 ] );
	return $_[ 1 ];
}

#
# max
#
# Returns the larger of two numbers.
#
# params:	[0] n1
#        	[1] n2
#
# returns:	maximum( n1, n2 )
#
sub max {
	return $_[ 0 ] if ( $_[ 0 ] > $_[ 1 ] );
	return $_[ 1 ];
}

#
# determineParserScale
#
# Determines whether or not the stroke data should be scaled before sending
# to the parser (i.e. whether or not data have decimal points). Currently,
# if scaling is to be done it is by a factor of 10^2, and remaining decimal
# places are rounded.
#
# params:	[0] reference to stroke data array
#
# returns:	n/a
#
sub determineParserScale {
	my $cref = $_[ 0 ]; # strokes
	my $needscale = 0;
	
	# determine scale factor
	SLOOP1: for ( my $i = 0; $i < @{ $cref }; $i++ ) {
		my $scref = $cref->[ $i ];
		SLOOP2: for ( my $j = 0; $j < @{ $scref }; $j++ ) {
			my $cpref = $scref->[ $j ];
			my $x = $cpref->[ 0 ];
			my $y = $cpref->[ 1 ];
			
			if ( $x =~ /^\d+\.(\d+)/ or $y =~ /^\d+\.(\d+)/ ) {
				$needscale = 1;
				last SLOOP2;
			}
			
			# print $x . " " . $y . "\n";
	
			# x coord
			# if ( $x =~ /^\d+\.(\d+)/ ) {
			#	my $dpts = length( $1 );
			#	$maxdpts = $dpts if ( $dpts > $maxdpts );
			#}
	
			# y coord
			#if ( $y =~ /^\d+\.(\d+)/ ) {
			#	my $dpts = length( $1 );
			#	$maxdpts = $dpts if ( $dpts > $maxdpts );
			#}
		}
		last SLOOP1 if ( $needscale != 0 );
	}
	
	$PARSER_SCALE = 100 if ( $needscale == 1 );
	
	if ( $VERBOSE ) {
		print "Scale need determined; scaling parser data by $PARSER_SCALE.\n";
	}
	
	# scale factor of 10^n, where n is the greatest number of decimal places
	# found in any coordinate
	# $scalefactor **= $maxdpts;
	# print "Scaling by a factor of 10**" . $maxdpts . " ...\n";
	
	# apply scale factor
	#for ( my $i = 0; $i < @{ $cref }; $i++ ) {
	#	my $scref = $cref->[ $i ];
	#	for ( my $j = 0; $j < @{ $scref }; $j++ ) {
	#		my $cpref = $scref->[ $j ];
	#		$cpref->[ 0 ] = $cpref->[ 0 ] * $scalefactor;
	#		$cpref->[ 1 ] = $cpref->[ 1 ] * $scalefactor;
	#		# print $cpref->[ 0 ] . " " . $cpref->[ 1 ] . "\n";		
	#	}
	#}
}

#
# charMapInit
#
# Initializes classifier->ICDAR symbol mapping.
#
# params:	n/a
#
# returns:	n/a
#
sub charMapInit {

	# ICDAR symbol set
	$ICDAR_CHAR_MAP{ "{" } = "\\{";
	$ICDAR_CHAR_MAP{ "}" } = "\\}";
	$ICDAR_CHAR_MAP{ "[" } = "[";
	$ICDAR_CHAR_MAP{ "]" } = "]";
	$ICDAR_CHAR_MAP{ "0" } = "0";
	$ICDAR_CHAR_MAP{ "1" } = "1";
	$ICDAR_CHAR_MAP{ "2" } = "2";
	$ICDAR_CHAR_MAP{ "3" } = "3";
	$ICDAR_CHAR_MAP{ "4" } = "4";
	$ICDAR_CHAR_MAP{ "5" } = "5";
	$ICDAR_CHAR_MAP{ "6" } = "6";
	$ICDAR_CHAR_MAP{ "7" } = "7";
	$ICDAR_CHAR_MAP{ "8" } = "8";
	$ICDAR_CHAR_MAP{ "9" } = "9";
	$ICDAR_CHAR_MAP{ "a_lower" } = "a";
	$ICDAR_CHAR_MAP{ "alpha" } = "\\alpha";
	$ICDAR_CHAR_MAP{ "A_upper" } = "A";
	$ICDAR_CHAR_MAP{ "beta" } = "\\beta";	
	$ICDAR_CHAR_MAP{ "b_lower" } = "b";
	$ICDAR_CHAR_MAP{ "B_upper" } = "B";	
	$ICDAR_CHAR_MAP{ "c_lower" } = "c";
	$ICDAR_CHAR_MAP{ "comma" } = ",";
	$ICDAR_CHAR_MAP{ "cos" } = "\\cos";
	$ICDAR_CHAR_MAP{ "C_upper" } = "C";	
	$ICDAR_CHAR_MAP{ "_dash" } = "-";
	$ICDAR_CHAR_MAP{ "div" } = "\\div";	
	$ICDAR_CHAR_MAP{ "dot" } = ".";
	$ICDAR_CHAR_MAP{ "d_lower" } = "d";
	$ICDAR_CHAR_MAP{ "e_lower" } = "e";
	$ICDAR_CHAR_MAP{ "_equal" } = "=";
	$ICDAR_CHAR_MAP{ "_excl" } = "!";	
	$ICDAR_CHAR_MAP{ "exists" } = "\\exists";
	$ICDAR_CHAR_MAP{ "f_lower" } = "f";
	$ICDAR_CHAR_MAP{ "forall" } = "\\forall";
	$ICDAR_CHAR_MAP{ "F_upper" } = "F";
	$ICDAR_CHAR_MAP{ "g_lower" } = "g";
	$ICDAR_CHAR_MAP{ "gamma" } = "\\gamma";
	$ICDAR_CHAR_MAP{ "geq" } = "\\geq";
	$ICDAR_CHAR_MAP{ "gt" } = "\\gt";
	$ICDAR_CHAR_MAP{ "i_lower" } = "i";
	$ICDAR_CHAR_MAP{ "in" } = "\\in";
	$ICDAR_CHAR_MAP{ "infty" } = "\\infty";
	$ICDAR_CHAR_MAP{ "int" } = "\\int";	
	$ICDAR_CHAR_MAP{ "j_lower" } = "j";
	$ICDAR_CHAR_MAP{ "k_lower" } = "k";
	$ICDAR_CHAR_MAP{ "ldots" } = "\\ldots";
	$ICDAR_CHAR_MAP{ "leq" } = "\\leq";
	$ICDAR_CHAR_MAP{ "lim" } = "\\lim";
	$ICDAR_CHAR_MAP{ "log" } = "\\log";
	$ICDAR_CHAR_MAP{ "_lparen" } = "(";
	$ICDAR_CHAR_MAP{ "lt" } = "\\lt";
	$ICDAR_CHAR_MAP{ "m_lower" } = "m";
	$ICDAR_CHAR_MAP{ "neq" } = "\\neq";	
	$ICDAR_CHAR_MAP{ "n_lower" } = "n";
	$ICDAR_CHAR_MAP{ "p_lower" } = "p";
	$ICDAR_CHAR_MAP{ "phi" } = "\\phi";
	$ICDAR_CHAR_MAP{ "pi" } = "\\pi";
	$ICDAR_CHAR_MAP{ "_plus" } = "+";
	$ICDAR_CHAR_MAP{ "pm" } = "\\pm";
	$ICDAR_CHAR_MAP{ "r_lower" } = "r";
	$ICDAR_CHAR_MAP{ "rightarrow" } = "\\rightarrow";
	$ICDAR_CHAR_MAP{ "_rparen" } = ")";
	$ICDAR_CHAR_MAP{ "sin" } = "\\sin";
	$ICDAR_CHAR_MAP{ "slash" } = "/";
	$ICDAR_CHAR_MAP{ "sqrt" } = "\\sqrt";
	$ICDAR_CHAR_MAP{ "sum" } = "\\sum";	
	$ICDAR_CHAR_MAP{ "t_lower" } = "t";
	$ICDAR_CHAR_MAP{ "tan" } = "\\tan";
	$ICDAR_CHAR_MAP{ "theta" } = "\\theta";	
	$ICDAR_CHAR_MAP{ "times" } = "\\times";
	$ICDAR_CHAR_MAP{ "X_upper" } = "X";
	$ICDAR_CHAR_MAP{ "x_lower" } = "x";
	$ICDAR_CHAR_MAP{ "Y_upper" } = "Y";
	$ICDAR_CHAR_MAP{ "y_lower" } = "y";
	$ICDAR_CHAR_MAP{ "z_lower" } = "z";
}

#
# symbolConvert
#
# Converts a symbol from classifier output to the corresponding symbol in the
# ICDAR symbol set.
#
# Remark: Unknown symbols will simply be propogated.
#
# params:	[0] classifer output symbol
#
# returns:	the mapped symbol
#
sub symbolConvert {
	my $sym = $_[ 0 ];
	
	if ( exists $ICDAR_CHAR_MAP{ $sym } ) {
		return $ICDAR_CHAR_MAP{ $sym };
	}
	
	print ">> WARNING (parse.pl): Unknown symbol " . $sym . " located.";
	return $sym; # unknown mapping
}

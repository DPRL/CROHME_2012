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
my $USAGE_MSG = "usage: gt2csv.pl input.inkml\n" .
	"   Output: a .csv file containing classification, bounding box\n"
	. "        and stroke data is written to the standard output.\n";

# Variables
my $xc;
my $filename;
my $outfile = "";
my $parser;
my @points;
my $PARSER_SCALE = 20;

# BEGIN EXECUTION
if ( @ARGV < 1 ) {
	print STDERR $USAGE_MSG;
	exit( 1 );
} else {
	# initialize and run
	$filename = $ARGV[ 0 ];
	
	# remove extension
	my $fname = $filename;
	$fname =~ s/\.inkml$//;
	
	parserInit();   # Create the XML tree.

	# get file tags to be used later
	my $fileui;
	foreach my $_node ( $xc->findnodes( '/ns:ink/ns:annotation' ) ) {
		if ( $_node->getAttribute( "type" ) eq "UI" ) {
			$fileui = $_node->textContent();
		}
	}
	#print "File UI: $fileui\n" if ( $VERBOSE );
	
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

	# Need to grab the outer traceGroup (containing the segmentation)
	# before the individual segments.
	my @tracegroups = $xc->findnodes( '/ns:ink/ns:traceGroup/ns:traceGroup' );
	my @classlist = $xc->findnodes('/ns:ink/ns:traceGroup/ns:traceGroup/ns:annotation');
	my $segid = "SEGID?";
	my $class = "CLASS?";
	my @strokes = ();
	my @classnode;
	my $k = 0;
	foreach ( @tracegroups ) {
		$segid = $_->getAttribute( 'xml:id' );
		$class = $classlist[$k]->textContent();
		my @strokenodes = $_->findall('./traceGroup');
		#foreach ( @strokenodes ) {
		#	print $strokenodes->textContent() . "\n";
		#}
		print scalar @strokenodes . "\n";

		print "$segid" . " " . $class . " " . @strokes . "\n";
		$k++;
	}

	#######################################
	# PRODUCING OUTPUT .csv FILE
	#######################################

	# Replace the trace (pen) data.
	#for ( my $i = 0; $i < scalar @rawtracecontent; $i++ ) {
	#	$inkml .= "\t<trace id=\"$i\">" . $rawtracecontent[ $i ] . "</trace>\n";
	#}

	print($outfile);
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
	
	#if ( $VERBOSE ) {
	#	print "Scale need determined; scaling parser data by $PARSER_SCALE.\n";
	#}
	
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


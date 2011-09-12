#!/usr/bin/env perl
use strict;


my $thumbnail = {
	width => 30,height=>120
};

my $maxlat = $thumbnail->{width} > $thumbnail->{height} ? $thumbnail->{width} : $thumbnail->{height};
my @sizes = (
	{ key => "large",min => 601,max=>10000 },
	{ key => "medium",min => 301,max => 600 },
	{ key => "small",min => 151,max=>300 },
	{ key => "thumbnail",min => 1,max => 150 }
);
foreach my $size(@sizes){
	if($maxlat >= $size->{min} && $maxlat <= $size->{max}){
		print "keeping this for $size->{key}\n";
	}elsif($maxlat > $size->{max}){
		print "making $size->{key}\n";
	}
}

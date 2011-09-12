#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use strict;
use XML::Simple;
use Catmandu::Store::Simple;
use LWP::UserAgent;
use Data::UUID;
use ExifTool;
use utf8;

my $parser = XML::Simple->new;
my $data = shift;

if(!-r $data){
	print STDERR "usage: $0 <file>\n";
	exit(1);
}

my $ua = LWP::UserAgent->new;
my $exif = ExifTool->new;
my $still_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/still_%s_V1.jpg";
my $media_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/media_%s_V1.mp4";
my $hash = $parser->XMLin($data,ForceArray=>1);
foreach my $record(@{$hash->{'oai_dc:dc'}}){
	my $newrecord = {};
	foreach my $key(keys %$record){
		next if $key !~ /^dc:(.*)$/;
		$newrecord->{$1} = $record->{$key};
	}	
	my $uuid;
	if($newrecord->{identifier}->[0] =~ /(.*)\.jpg$/){
		$uuid = $1;
	}
	my $file = sprintf($still_template,$uuid,$uuid);
	print "$file\n";
	my $response = $ua->get($file);
	if($response->is_error || $response->content_type ne "image/jpeg"){
		print "error, skipping..\n";
		next;
	}
	my $temp = "/tmp/".Data::UUID->new->create_str.".jpeg";
	open FILE,">$temp" or die($!);
	print FILE $response->content;
	close FILE;
	
	my $info = $exif->ImageInfo($temp);

	unlink $temp;
}

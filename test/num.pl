#!/usr/bin/env perl
use strict;
use utf8;
use XML::Simple;

my $data = shift;

if(!-r $data){
	print STDERR "usage: $0 <file>\n";
	exit(1);
}

my $parser = XML::Simple->new;

my $still_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/still_%s_V1.jpg";

my $hash = $parser->XMLin($data,ForceArray=>1);
print "num:".scalar(@{$hash->{'oai_dc:dc'}})."\n";
exit 0;

foreach my $record(@{$hash->{'oai_dc:dc'}}){
	#metadata
	my $metadatarecord = {};
	foreach my $key(keys %$record){
		next if $key !~ /^dc:(.*)$/;
		$metadatarecord->{$1} = $record->{$key};
	}	
	#afleiden media
	my $uuid;
	if($metadatarecord->{identifier}->[0] =~ /(.*)\.jpg$/){
		$uuid = $1;
		$metadatarecord->{_id} = $uuid;
	}
	my $still_url = sprintf($still_template,$uuid,$uuid);
	print "$still_url\n";
}

#!/usr/bin/env perl
use strict;
BEGIN {
	push @INC,$ENV{HOME}."/Catmandu/lib";
}
use Catmandu::Store::Simple;
use Cache::FastMmap;
use Data::Dumper;

my @ids = ();
my $file = shift;
open FILE,$file or die($!);
while(<FILE>){
	chomp;
	push @ids,$_;
}
close FILE;

my $store = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/media.db");
my $cache = Cache::FastMmap->new(
	cache_size => '50m',
	context => $store,
	read_cb => sub {
		print " not found in cache, so retrieving from database";
		return $_[0]->load($_[1]);		
	}
);
foreach(@ids){
	print $_;
	my $val = $cache->get($_);
	print "\n";
	#print Dumper($val);
}
foreach(@ids){
        #print $_;
        my $val = $cache->get($_);
	#print "\n";
        #print Dumper($val);
}

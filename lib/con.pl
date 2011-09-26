#!/usr/bin/env perl
use strict;
use lib $ENV{HOME}."/Catmandu/lib";
use Catmandu::Store::Simple;
use Data::Dumper;

my $in = Catmandu::Store::Simple->new(path=>shift);
my $out = Catmandu::Store::Simple->new(path=>shift);

$in->each(sub{
	my $record = shift;
	my $services = ["videostreaming"];
	foreach my $dev(keys %{$record->{media}->[0]->{devs}}){
		push @$services,$dev;
	}
	$record->{media}->[0]->{services} = $services;
	$out->save($record);
});

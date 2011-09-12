#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use strict;
use Catmandu::Store::Simple;

my $in = Catmandu::Store::Simple->new(path=>"/tmp/media.db");
my $out = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/media.db");
$in->each(sub{
	my $record = shift;
	print $record->{_id}."\n";
	$out->save($record);
});

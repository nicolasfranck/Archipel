#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use strict;
use Catmandu::Store::Simple;

my $re = qr/^oai\:archipel\-project\.be\:/;
my $in = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/metadata.db.has.vti");
my $out = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/metadata.db");
$in->each(sub{
	my $record = shift;
	if($record->{_id} =~ $re){
		print $record->{_id}."\n";
		$out->save($record);
	}
});

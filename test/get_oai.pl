#!/usr/bin/perl 
use strict;
use lib $ENV{HOME}."/Catmandu/lib";
use Catmandu::Store::Simple;

my $in = Catmandu::Store::Simple->new(path=>shift);
my $out = Catmandu::Store::Simple->new(path=>shift);

$in->each(sub{
	my $record = shift;
	if($record->{_id} =~ /^oai/io){
		print $record->{_id}."\n";
		$out->save($record);
	}
});

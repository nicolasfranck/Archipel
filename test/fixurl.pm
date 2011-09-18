#!/usr/bin/env perl
use strict;
use lib $ENV{HOME}."/Catmandu/lib";
use Catmandu::Store::Simple;

my $a = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/media.db");
my $b = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/media_fixed.db");

my $find = "(localhost|127.0.0.1)";
my $replace = "50.17.222.182";

$a->each(sub{
	my $record = shift;
	foreach my $item(@{$record->{media}}){
		foreach my $type(keys %{$item->{devs}}){
			if($item->{devs}->{$type}->{url}){
				$item->{devs}->{$type}->{url} =~ s/$find/$replace/;
				print $item->{devs}->{$type}->{url}."\n";
			}
		}
	}
	$b->save($record);
});

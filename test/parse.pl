#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use strict;
use XML::Simple;
use Catmandu::Store::Simple;

my $parser = XML::Simple->new;
my $hash = $parser->XMLin(shift,NoAttr=>1,ForceArray=>1);
my $store = Catmandu::Store::Simple->new(path=>shift);
foreach my $record(@{$hash->{'oai_dc:dc'}}){
	my $new_record = {};
	foreach my $key(keys %$record){
		my $new_key = $key;
		$new_key =~ s/^dc://;
		if(ref $record->{$key} eq "ARRAY"){
			$new_record->{$new_key} = [];
			push @{$new_record->{$new_key}},$_ foreach(@{$record->{$key}});
		}
		else {
			$new_record->{$new_key} = [$record->{$key}];
		}
	}
	$new_record->{_id} = $new_record->{identifier}->[0];
	print $new_record->{_id}."\n";
	$store->save($new_record);
}

#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use strict;
use Catmandu::Store::Simple;

my $re = qr/^oai\:archipel\-project\.be\:/;
my $in = Catmandu::Store::Simple->new(path=>$ENV{HOME}."/data/media.db");
my $out = Catmandu::Store::Simple->new(path=>"/tmp/media-out.db");
$in->each(sub{
	my $record = shift;
	print $record->{_id}."\n";
	if($record->{_id} =~ $re){
		for(my $i = 0;$i<scalar(@{$record->{media}});$i++){
			$record->{media}->[$i]->{devs}->{$_}->{no_proxy} = 1 foreach(keys %{$record->{media}->[$i]->{devs}});
		}
	}
	$out->save($record) if defined($record->{media});
});

#!/usr/bin/env perl
use lib $ENV{HOME}."/Archipel/lib";
use strict;
use Rft::Fedora;

my $parser = Rft::Fedora->new;
my $rft_id = shift;
#$rft_id =~ s/^([\w_\-]+)_\d{4}_(\d{4})_AC$/\1_????_\2_AC/;
#print "$rft_id\n";

$parser->parse($rft_id);
print "query => ".$parser->query."\n";
print "item_id => ".$parser->item_id."\n";
print "hint => ".$parser->hint."\n";

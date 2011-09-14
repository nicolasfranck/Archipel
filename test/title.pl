#!/usr/bin/env perl
use strict;
use utf8;

binmode(STDOUT,":encoding(utf8)");

my $title = "test[CHÂTEAUX.] [graphic material]";
print "title => $title\n";
$title =~ s/\[(?:graphic material)\]$//gi;
        $title =~ s/\/.*$//;
        $title =~ s/://g;
print "title => $title\n";

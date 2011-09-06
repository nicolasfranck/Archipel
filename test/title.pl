#!/usr/bin/env perl
use strict;
use utf8;

my $title = "test[CHÂTEAUX.] [graphic material]";
print "title => $title\n";
$title =~ /(\[[^\[\]]*?\])$/;
print "catch => $1\n";
$title =~ s/\[[^\[\]]*?\]$//;
print "title => $title\n";
$title =~ s/\/.*$//;
print "title => $title\n";
$title =~ s/://g;
print "title => $title\n";


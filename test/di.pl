#!/usr/bin/env perl
use strict;
use Data::Dumper;

my %list1 = ();
my %list2 = ();

my $dir1 = shift;
my $dir2 = shift;

open CMD,"find $dir1 -type f |" or die($!);
while(<CMD>){
	chomp;
	$list1{$_} = 1;
}
close CMD;

open CMD,"find $dir2 -type f |" or die($!);
while(<CMD>){
        chomp;
        $list2{$_} = 1;
}
close CMD;

foreach my $file(keys %list1){
	print "$file\n";
	my $find = $file;
	$find =~ s/$dir1/$dir2/;
	print " <=> $find\n";
	if($list2{$find}){
		open CMD,"diff $file $find |" or die($!);
		print $_ while(<CMD>);
		close CMD;
	}else{
		"$file not in $dir2\n";
	}
}

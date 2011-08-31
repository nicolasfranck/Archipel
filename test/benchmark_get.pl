#!/usr/bin/env perl
BEGIN{
	push @INC,$ENV{HOME}.'/Catmandu/lib'
}
use LWP::UserAgent;
use Benchmark;
use Catmandu::Store::Simple;
use Time::HiRes;
use Data::Dumper;
use strict;

sub logger {
	my $msg = shift;
	open FILE,">benchmark.log";
	print FILE $$msg;
	close FILE;
}
my $baseurl = "http://localhost:5000/OpenURL/resolve";
my $ua = LWP::UserAgent->new();
my $db = Catmandu::Store::Simple->new(path=>$ENV{HOME}.'/data/media.db');
my $count = 0;
my $sumseconds = 0;
$db->each(sub{
	my $record = shift;
	foreach my $item(@{$record->{media}}){
		foreach my $file(@{$item->{file}}){
			my $url = "$baseurl?rft_id=".$record->{_id}.":".$item->{item_id}."&svc_id=large";
			my $start = Time::HiRes::time();
			my $response = $ua->head($url);
			if($response->is_error){
				next;
				logger($response->content_ref);
				die("error in ".$record->{_id}.", see benchmark.log\n");
			}
			my $end = Time::HiRes::time();
			
			print "$url => ";
			$sumseconds += ($end-$start);
			print "".($end - $start)."\n";
			$count++;
		}
	}
});
print "\naverage:".($sumseconds / $count)." seconds\n";

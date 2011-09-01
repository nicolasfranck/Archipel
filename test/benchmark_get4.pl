#!/usr/bin/env perl
use lib $ENV{HOME}.'/Catmandu/lib';
use LWP::UserAgent;
use Benchmark;
use Catmandu::Index::Solr;
use Time::HiRes;
use Try::Tiny;
use strict;

sub logger {
	my $msg = shift;
	open FILE,">benchmark.log";
	print FILE $$msg;
	close FILE;
}
my $baseurl = "http://localhost/OpenURL/resolve";
my $ua = LWP::UserAgent->new();
my $index = Catmandu::Index::Solr->new(url=>"http://localhost:8983/solr/core0",id_field=>"id");
my $count = 0;
my $sumseconds = 0;

try{
	my($hits,$totalhits)=$index->search("*",rows=>500);
	foreach my $hit(@$hits){
		my @files = split(' ',$hit->{files});
		foreach my $file(@files){
			my $url = "$baseurl?rft_id=$file&svc_id=thumbnail";
			print "$url => ";
			my $start = Time::HiRes::time();
			my $response = $ua->head($url);
			if($response->is_error || $response->content_type ne "image/jpeg"){
				print "status code:".$response->code."\n";
				logger($response->content_ref);
				die("error in ".$hit->{id}.", see benchmark.log\n");
			}
			my $end = Time::HiRes::time();
			$sumseconds += ($end-$start);
			print "".($end - $start)."\n";
			$count++;
		}
	}
	print "totalhits:$totalhits\n";
	$count = 1 if $totalhits == 0;
}catch{
	print $_;
};
print "\naverage:".($sumseconds / $count)." seconds\n";

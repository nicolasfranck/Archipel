#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use lib $ENV{HOME}."/PeepShow/lib";

use strict;
use XML::Simple;
use Catmandu::Store::Simple;
use LWP::UserAgent;
use Data::UUID;
use Image::ExifTool;
use utf8;
use Clone qw(clone);
use Image::Magick::Thumbnail::Simple;
use Catmandu::Cmd::Stats;
use File::Path qw(mkpath);

sub choose_path{
        my $addpath;
        my($second,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime time;
        $year += 1900;
        $addpath = "$year/$mon/$mday/$hour/$min/$second";
        return $addpath;
}

my $data = shift;

if(!-r $data){
	print STDERR "usage: $0 <file>\n";
	exit(1);
}

my @sizes = (
        { key => "large",min => 601,max=>10000 },
        { key => "medium",min => 301,max => 600 },
        { key => "small",min => 151,max=>300 },
        { key => "thumbnail",min => 1,max => 150 }
);

my $parser = XML::Simple->new;
my $ua = LWP::UserAgent->new;
my $exif = Image::ExifTool->new;
my $thumber = Image::Magick::Thumbnail::Simple->new;
my $stats = Catmandu::Cmd::Stats->new;

my $still_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/still_%s_V1.jpg";
my $media_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/media_%s_V1.mp4";


my $media = Catmandu::Store::Simple->new(path=>'/tmp/media.db');
my $meta = Catmandu::Store::Simple->new(path=>'/tmp/meta.db');

my $hash = $parser->XMLin($data,ForceArray=>1);
foreach my $record(@{$hash->{'oai_dc:dc'}}){

	#metadata
	my $metadatarecord = {};
	foreach my $key(keys %$record){
		next if $key !~ /^dc:(.*)$/;
		$metadatarecord->{$1} = $record->{$key};
	}	
	#afleiden media
	my $uuid;
	if($metadatarecord->{identifier}->[0] =~ /(.*)\.jpg$/){
		$uuid = $1;
		$metadatarecord->{_id} = $uuid;
	}
	my $still_url = sprintf($still_template,$uuid,$uuid);
	print "$still_url\n";
	my $response = $ua->get($still_url);
	if($response->is_error || $response->content_type ne "image/jpeg"){
		print "error, skipping..\n";
		next;
	}
	my $tempfile = "/tmp/".Data::UUID->new->create_str.".jpeg";
	open FILE,">$tempfile" or die($!);
	print FILE $response->content;
	close FILE;
	
	my $still_info = $exif->ImageInfo($tempfile);
	
	#wat kunnen we uit deze still_url halen?
	my $devs = {};
	my $maxlat = $still_info->{ImageWidth} > $still_info->{ImageHeight} ? $still_info->{ImageWidth} : $still_info->{ImageHeight};
	foreach my $size(@sizes){
                my $dev = {};
                if($maxlat >= $size->{min} && $maxlat <= $size->{max}){
                        print "\tkeeping this for $size->{key}\n";
                        $dev->{url} = $still_url;
                        $dev->{width} = $still_info->{ImageWidth};
                        $dev->{height} = $still_info->{ImageHeight};
                        $dev->{size} = -s $tempfile;
                        $dev->{content_type} = $still_info->{MIMEType};
                }elsif($maxlat > $size->{max}){
                        print "\tmaking $size->{key}\n";
                        my $added_path = &choose_path();
                        my $basename = Data::UUID->new->create_str.".jpeg";
                        my $output = "/data/thumbies/$added_path/$basename";
			mkpath("/data/thumbies/$added_path");
                        my $success = $thumber->thumbnail(
                                size => $size->{max},
                                input => $tempfile,
                                output => $output
                        );
                        if(!$success){
                                die($thumber->error."\n");
                        }
                        my $dev_info = $exif->ImageInfo($output);
                        $dev = {
                                %{$stats->stat_properties($output)},
                                content_type => $dev_info->{MIMEType},
                                width => $dev_info->{ImageWidth},
                                height => $dev_info->{ImageHeight},
                                url => "http://localhost/thumbies/$added_path/$basename"
                        };
                }
                $devs->{$size->{key}} = $dev;
        }
	
	my $mediarecord = {
		_id => $metadatarecord->{_id},
                access => {
                        services => { map {$_ => 1} keys %$devs }
                },
		poster_item_id => 1,
		media => [{
			item_id => 1,
			context => "Image",
			file => [],
			services => [keys %$devs],
			devs => clone($devs)			
		}],
	};
	$meta->save($metadatarecord);
	$media->save($mediarecord);
	unlink $tempfile;
}

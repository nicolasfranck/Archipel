#!/usr/bin/env perl
use lib $ENV{HOME}."/Catmandu/lib";
use strict;
use XML::Simple;
use Catmandu::Store::Simple;
use LWP::UserAgent;
use Data::UUID;
use Image::ExifTool;
use utf8;
use Clone qw(clone);

my $parser = XML::Simple->new;
my $data = shift;

if(!-r $data){
	print STDERR "usage: $0 <file>\n";
	exit(1);
}

my $ua = LWP::UserAgent->new;
my $exif = Image::ExifTool->new;
my $still_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/still_%s_V1.jpg";
my $media_template = "http://archipellod.demo.ibbt.be:8080/files/KADOC/%s/media_%s_V1.mp4";

my $media = Catmandu::Store::Simple->new(path=>'/tmp/media.db');
my $meta = Catmandu::Store::Simple->new(path=>'/tmp/meta.db');

my $hash = $parser->XMLin($data,ForceArray=>1);
foreach my $record(@{$hash->{'oai_dc:dc'}}){
	my $metadatarecord = {};
	foreach my $key(keys %$record){
		next if $key !~ /^dc:(.*)$/;
		$metadatarecord->{$1} = $record->{$key};
	}	
	my $uuid;
	if($metadatarecord->{identifier}->[0] =~ /(.*)\.jpg$/){
		$uuid = $1;
		$metadatarecord->{_id} = $uuid;
	}
	my $file = sprintf($still_template,$uuid,$uuid);
	print "$file\n";
	foreach(@{$metadatarecord->{relation}}){
		if(/media/){
			print "$_\n";
		}
	}
	my $response = $ua->get($file);
	if($response->is_error || $response->content_type ne "image/jpeg"){
		print "error, skipping..\n";
		next;
	}
	my $temp = "/tmp/".Data::UUID->new->create_str.".jpeg";
	open FILE,">$temp" or die($!);
	print FILE $response->content;
	close FILE;
	
	my $info = $exif->ImageInfo($temp);
	my $thumbnail = {};
	$thumbnail->{url} = $file;
	$thumbnail->{width} = $info->{ImageWidth};
	$thumbnail->{height} = $info->{ImageHeight};
	$thumbnail->{content_type} = $info->{MIMEType};
	$thumbnail->{size} = -s $temp;
	
	my $mediarecord = {
		_id => $metadatarecord->{_id},
                access => {
                        services => {thumbnail=>1}
                },
		poster_item_id => 1,
		media => [{
			item_id => 1,
			context => "Video",
			file => [],
			services => ["thumbnail"],
			devs => {
				thumbnail => clone($thumbnail)
			}			
		}],
	};
	$meta->save($metadatarecord);
	$media->save($mediarecord);
	unlink $temp;
}

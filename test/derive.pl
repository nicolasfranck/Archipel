#!/usr/bin/env perl
use strict;
use lib $ENV{HOME}."/Catmandu/lib";
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use Image::Magick::Thumbnail::Simple;
use Image::ExifTool;

my @sizes = (
        { key => "large",min => 601,max=>10000 },
        { key => "medium",min => 301,max => 600 },
        { key => "small",min => 151,max=>300 },
        { key => "thumbnail",min => 1,max => 150 }
);

my $in = Catmandu::Store::Simple->new(path=>shift);
my $out = Catmandu::Store::Simple->new(path=>shift);
my $thumber = Image::Magick::Thumbnail::Simple->new;
my $index = Catmandu::Index::Solr->new(url=>"http://localhost:8983/solr/core0",id_field=>"id");
my $exif = Image::ExifTool->new;

my($records,$totalrecords)=$index->search("vti",reify=>$in,limit=>10000);
foreach my $record(@$records){
	print $record->{_id}."\n";
			
}


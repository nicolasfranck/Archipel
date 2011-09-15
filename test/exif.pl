#!/usr/bin/env perl
use Image::ExifTool qw(ImageInfo);
use Data::Dumper;

print Dumper(ImageInfo(shift));

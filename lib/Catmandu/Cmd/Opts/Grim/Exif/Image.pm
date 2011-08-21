package Catmandu::Cmd::Opts::Grim::Exif::Image;
our $VERSION = 0.01;# VERSION
use Moose::Role;
use Image::ExifTool;

has _exif => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
                Image::ExifTool->new();
        }
);
sub is_jpeg{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->_exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "JPEG";
        return 0 if $info->{MIMEType} ne "image/jpeg";
        return 1;
}
sub is_jp2k{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->_exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "JP2";
        return 0 if $info->{MIMEType} ne "image/jp2";
        return 1;
}
sub is_tiff{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->_exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "TIFF";
        return 0 if $info->{MIMEType} ne "image/tiff";
        return 0 if not (defined($info->{TileWidth}) && defined($info->{TileLength}));
        return 0 if not defined($info->{TileByteCounts});
        return 1;
}

no Moose::Role;
1;

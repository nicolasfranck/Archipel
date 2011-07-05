package Catmandu::Cmd::Command::checktiff;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

use Image::ExifTool;

has storetype => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 's',
    documentation => "Type of store [default:Simple]",
        default => sub{"Simple";}
);

has db_args => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]",
        required => 1
);

has exif => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		Image::ExifTool->new();
	}
);


sub is_tiff{
	my($self,$file)=@_;
	return 0 if not defined($file);
	return 0 if not -f $file;
	return 0 if -s $file == 0;
	my $info = $self->exif->ImageInfo($file);
	return 0 if defined($info->{Error});
	return 0 if $info->{FileType} ne "TIFF";
	return 0 if $info->{MIMEType} ne "image/tiff";
	return 0 if not (defined($info->{TileWidth}) && defined($info->{TileLength}));
	return 0 if not defined($info->{TileByteCounts});
	return 1;	
}

sub execute{
        my($self,$opts,$args)=@_;

	my $class = "Catmandu::Store::".$self->storetype;
	Plack::Util::load_class($class) or die();
	my $store = $class->new(%{$self->db_args});
	$store->each(sub{
		my $record = shift;
		print $record->{_id}."\n";
		foreach my $item(@{$record->{media}}){
			foreach my $file(@{$item->{file}}){				
				next if $file->{content_type} ne "image/tiff";
				if($self->is_tiff($file->{path})){
					print $file->{path}." [VALID PYRAMID TIFF]\n";
				}else{
					print $file->{path}." [NOT A VALID PYRAMID TIFF]\n";
				}
			}
		}
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

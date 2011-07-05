package Catmandu::Cmd::Command::checkjpeg2000;
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

sub is_jp2k{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "JP2";
        return 0 if $info->{MIMEType} ne "image/jp2";
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
				next if $file->{content_type} ne "image/jp2";
				if($self->is_jp2k($file->{path})){
					print $file->{path}." [VALID JPEG2000]\n";
				}else{
					print $file->{path}." [NOT A VALID JPEG2000]\n";
				}
			}
		}
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

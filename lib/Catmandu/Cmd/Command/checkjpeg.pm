package Catmandu::Cmd::Command::checkjpeg;
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


sub is_jpeg{
	my($self,$file)=@_;
	return 0 if not defined($file);
        return 0 if not -f $file;
	return 0 if -s $file == 0;
        my $info = $self->exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "JPEG";
        return 0 if $info->{MIMEType} ne "image/jpeg";
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
			foreach my $svc_id(keys %{$item->{devs}}){
				my $path = $item->{devs}->{$svc_id}->{path};
				if(defined($path)){				
					if($self->is_jpeg($path)){
						print "$path [VALID JPEG]\n";
                                	}else{
						print "$path [NOT A VALID JPEG]\n";
                                	}				
				}
			}
		}
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

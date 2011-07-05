package Catmandu::Cmd::Command::orientation;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;

extends qw(Catmandu::Cmd::Command);
use Image::ExifTool;

has file => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'f',
    documentation => "file [required]",
    required => 1
);
has _exif => (
	is => 'ro',
	isa => 'Ref',
	default => sub{Image::ExifTool->new;}
);
sub orientation {
	my($self,$file)=@_;
	$self->_exif->ImageInfo($file)->{Orientation};
}

sub execute{
        my($self,$opts,$args)=@_;
	my @files = ();
	if(-r $self->file){
		open FILE,$self->file or die($!);
		while(<FILE>){
			chomp;
			push @files,$_;
		}
		close FILE;
	}else{
		die("file is not readable or does not exist\n");
	}
	foreach my $file(@files){
		print "$file ";
		if(!-r $file){
			print "is not readable or does not exist\n";
		}else{
			print $self->orientation($file)."\n";
		}
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;


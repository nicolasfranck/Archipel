package Catmandu::Cmd::Command::watermark;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;
#modules vereist voor dit commando specifiek
use File::Find;
use File::Basename;
#belangrijk: werkt enkel volledig met laatste versie van Perlmagick, meegeleverd met de bron van Image::Magick (6.6.4-10.7 momenteel)
#reden: dissolve werkt niet in vorige versies van Perlmagick (hoewel de binaries er geen problemen mee hebben)
use Image::Magick;
use File::Temp qw(tmpnam);
use File::Copy;

extends qw(Catmandu::Cmd::Command);

has input => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'ArrayRef[Str]',
    cmd_aliases => 'i',
    documentation => "Directories to follow in search for images",
    default => sub{
	["."];
    }
);

has dest => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'o',
    documentation => "Directory to copy the newly created files to ('r':replaces original files)",
    required => 1
);

has watermark => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'w',
    documentation => "Location of png file to use as watermark",
    required => 1
);

has filter => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'f',
    documentation => "Filters out the possible extension to mark [default: '\.jpeg\$']",
	default => sub{
		'\.jpeg$';
	}
);
has tile => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Bool',
    cmd_aliases => 't',
    documentation => "The mark covers the whole image surface",
	default => sub{0;}	
);
has dissolve => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'd',
    documentation => "Dissolving applied to the watermark[default:'50%']",
	default => sub{"50%";}		
);
has gravity => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'g',
    documentation => "Place on the image where the watermark is placed [default:'center']. This option does not help when using --tile (-t).",
	default => sub{"center";}		
);



sub execute{
	my($self,$opts,$args)=@_;	
	my $watermark = Image::Magick->new();
	my $result = $watermark->ReadImage($self->watermark);		
	my $filter = $self->filter;
	my $re = qr/$filter/i;
	find({
		preprocess => sub{
			my @files = ();
			foreach(@_){
				my $f = $File::Find::dir."/$_";
				push @files,$_ if -d $f || (-f $f && $f =~ $re);
			}
			@files;
		},	
		wanted => sub{
			return if -d $File::Find::name;
			my $file = $File::Find::name;
			my $basename = $_;
			my $pdot = rindex($basename,'.');
                        my $base = substr($basename,0,$pdot);
                        my $ext = substr($basename,$pdot+1);
                        my $image = Image::Magick->new();
                        $result = $image->ReadImage($file);
                        my %o = (
                        	image=>$watermark,
                                compose => 'Dissolve'
                        );
                        $o{tile}=1 if $self->tile;
                        $o{gravity}=$self->gravity;
                        $o{opacity}=$self->dissolve;
                        $result = $image->Composite(%o);
                        if($self->dest eq "r"){
                        	my $tempfile = tmpnam();
                                my $res = $image->Write($tempfile);
                                if("$res"){
                                	warn "$res";
                                }else{
                                	print "$tempfile -> $file\n";
                                        move($tempfile,$file) or die($!);
                                }
                        }else{
                        	my $res = $image->Write($self->dest."/$base.$ext");
                                warn "$res" if "$res";
                        }

		}
	},@{$self->input});
}
__PACKAGE__->meta->make_immutable;
no Moose;
__END__

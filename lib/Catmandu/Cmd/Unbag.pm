package Catmandu::Cmd::Unbag;
use strict;
use warnings;
use IO::Tee;
use Image::ExifTool;
use parent qw(Catmandu::Cmd::Stats);

sub new {
	my($class,%opts)=@_;
	bless {
		err => undef,
		out=> undef,
		exitcode => 0,
		input_info => {},
		output_info => {},
		tempdir => $opts{tempdir} || "/tmp",
		devs => {thumbnail => {axis=>150},small => {axis=>300}},
		printer => (ref($opts{printer}) eq "IO::Tee")? $opts{printer}:IO::Tee->new(\*STDOUT),
		exif => Image::ExifTool->new
	},$class;
	
}
sub err {
	my $self = shift;
	if(@_){$self->{err}=shift;}
	$self->{err};
}
sub out {
        my $self = shift;
        if(@_){$self->{out}=shift;}
        $self->{out};
}
sub print {
	my $self = shift;
	if(@_){$self->{printer}->print("\t",@_);}
	$self->{printer};
}
sub exitcode {
        my $self = shift;
        if(@_){$self->{exitcode}=shift;}
        $self->{exitcode};
}
sub tempdir {
	my $self = shift;
	if(@_){$self->{tempdir}=shift;}
	$self->{tempdir};
}
sub devs {
	$_[0]->{devs};
}
sub choose_path{
        my $self = shift;
        my $addpath;
        my($second,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime time;
        $year += 1900;
        $addpath = "$year/$mon/$mday/$hour/$min/$second";
        return $addpath;
}
sub exif {
	$_[0]->{exif};
}
sub is_image{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->exif->ImageInfo($file);
        return not defined($info->{Error});
}
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
sub input_info {
	my $self = shift;
	if(@_){$self->{input_info}=shift;}
        $self->{input_info};
}
sub output_info {
        my $self = shift;
        if(@_){$self->{output_info}=shift;}
        $self->{output_info};
}
1;

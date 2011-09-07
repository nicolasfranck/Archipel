package Catmandu::Cmd::Command::insert2media;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#eigen module
use Catmandu::Store::Simple;
use File::Basename;
use File::Copy;
use File::Path qw(mkpath);
use IO::Tee;
use IO::File;
use Date::Parse;

has dbin => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Database arguments for the temporary media database [required]",
    required => 1
);

has dbout => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'o',
    documentation => "Database arguments for the final media database [required]",
    required => 1
);
has _dbin => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		my $self = shift;
		Catmandu::Store::Simple->new(%{$self->{dbin}}) or die("could not open source database");
	}
);
has _dbout => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->{dbout}}) or die("could not open destination database");
        }
);

has datadir => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'd',
    documentation => "Final directory to store the originals [required]",
    required => 1
);

has thumbdir => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 't',
    documentation => "Final directory to store the thumbs [required]",
    required => 1
);
has tee => (
        is => 'rw',
        isa => 'IO::Tee',
        lazy => 1,
        default => sub{
                my $self = shift;
                open STDERR,">/tmp/insert2media-".time.".err";
                IO::Tee->new(
                        \*STDOUT,IO::File->new(">/tmp/insert2media-".time.".log")
                );
        }
);
has thumb_prefix_url => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'tp',
    documentation => "prefix url for the thumbnail",
    required => 1
);
has file_prefix_url => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'fp',
    documentation => "prefix url for the file",
    required => 0
);
has existing_records => (
	is => 'rw',
	isa => 'IO::File',
	default => sub{IO::File->new(">/tmp/insert2media-".time."-existingrecords.log");}
);
sub choose_path{
        my $self = shift;
        my $addpath;
        my($second,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime time;
        $year += 1900;
        $addpath = "$year/$mon/$mday/$hour/$min/$second";
        return $addpath;
}
sub record_exists{
	my($self,$id)=@_;
	defined($self->_dbout->load($id));
}

sub execute{
        my($self,$opts,$args)=@_;
	die($self->datadir." is not writable or does not exist") if not -w $self->datadir;
	die($self->thumbdir." is not writable or does not exist") if not -w $self->thumbdir;
	#voer databank in
	$self->_dbin->each(sub{
		my $record = shift;
		$self->tee->print($record->{_id}."\n");
		#check
		if($self->record_exists($record->{_id})){
			$self->tee->print($record->{_id}." exists, so skipping this one\n");
			$self->existing_records->print($record->{_id}."\n");
			return;
		}
		
		#wijzig en verwijder extra info
		foreach my $item(@{$record->{media}}){
			for(my $i = 0;$i<scalar(@{$item->{file}});$i++){
				my $subpath = $self->choose_path."/".basename($item->{file}->[$i]->{path});
				my $newpath = $self->datadir."/$subpath";
				my $dirname = dirname($newpath);
				mkpath($dirname);
				print "\tcopying $item->{file}->[$i]->{path} to $newpath\n";
				copy($item->{file}->[$i]->{path},$newpath);
				$item->{file}->[$i]->{path}=$newpath;
				if($self->file_prefix_url){
					$item->{file}->[$i]->{url} = $self->file_prefix_url."/$subpath";
					print "\t url is $item->{file}->[$i]->{url}\n";
				}
			}
			foreach my $key(keys %{$item->{devs}}){
				my $subpath = $self->choose_path."/".basename($item->{devs}->{$key}->{path});
				my $newpath = $self->thumbdir."/$subpath";
				my $dirname = dirname($newpath);
				mkpath($dirname);
				print "\tcopying $item->{devs}->{$key}->{path} to $newpath\n";
				copy($item->{devs}->{$key}->{path},$newpath);
				$item->{devs}->{$key}->{path}=$newpath;
				$item->{devs}->{$key}->{url} = $self->thumb_prefix_url."/$subpath";
				print "\turl is $item->{devs}->{$key}->{url}\n";
			}
		}
		#en saven maar		
		$self->_dbout->save($record);		
	});
	#gelukt? Aha!
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

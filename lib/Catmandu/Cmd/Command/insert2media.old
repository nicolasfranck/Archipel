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
has existing_records => (
	is => 'rw',
	isa => 'IO::File',
	default => sub{IO::File->new(">/tmp/insert2media-".time."-existingrecords.log");}
);
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
		my $tmp_datadir = $record->{tmp_datadir};
		my $tmp_thumbdir = $record->{tmp_thumbdir};
		die("tmp_datadir $tmp_datadir is not readable or does not exist!") if not -r $tmp_datadir;
		die("tmp_thumbdir $tmp_thumbdir is not readable or does not exist!") if not -r $tmp_thumbdir;
		#wijzig en verwijder extra info
		foreach my $item(@{$record->{media}}){
			for(my $i = 0;$i<scalar(@{$item->{file}});$i++){
				my $newpath = $self->datadir."/".$item->{file}->[$i]->{tmp_sublocation};
				my $dirname = dirname($newpath);
				mkpath($dirname);
				copy($item->{file}->[$i]->{path},$newpath);
				$item->{file}->[$i]->{path}=$newpath;
				delete $item->{file}->[$i]->{tmp_sublocation};
			}
			foreach my $key(keys %{$item->{devs}}){
				my $newpath = $self->thumbdir."/".$item->{devs}->{$key}->{tmp_sublocation};
				my $dirname = dirname($newpath);
				mkpath($dirname);
				copy($item->{devs}->{$key}->{path},$newpath);
				$item->{devs}->{$key}->{path}=$newpath;
				delete $item->{devs}->{$key}->{tmp_sublocation};
			}
		}
		delete $record->{tmp_datadir};
		delete $record->{tmp_thumbdir};
		#en saven maar		
		$self->_dbout->save($record);		
	});
	#gelukt? Aha!
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

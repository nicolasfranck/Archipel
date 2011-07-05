package Catmandu::Cmd::Command::insert2meta;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#eigen module
use Catmandu::Store::Simple;
use IO::Tee;
use IO::File;

has dbin => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Database arguments for the final metadata database [required]",
    required => 1
);

has dbout => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'o',
    documentation => "Database arguments for the final metadata database [required]",
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
has _tee => (
        is => 'rw',
        isa => 'IO::Tee',
        lazy => 1,
        default => sub{
                my $self = shift;
                open STDERR,">/tmp/insert2meta-".time.".err";
                IO::Tee->new(
                        \*STDOUT,IO::File->new(">/tmp/insert2meta-".time.".log")
                );
        }
);


sub execute{
        my($self,$opts,$args)=@_;

        #voer databank in
	my $count=0;my $skipped=0;
	$self->_dbout->transaction(sub{
		$self->_dbin->each(sub{
			my $record = shift;
			$self->_tee->print($record->{_id}."\n");
			#en saven maar          
			$self->_dbout->save($record);
		});
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;


package Catmandu::Cmd::Command::rmbag;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#eigen module
use Catmandu::Store::Simple;

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

sub execute{
        my($self,$opts,$args)=@_;
	$self->_dbout->transaction(sub{
		$self->_dbin->each(sub{
			my $record = shift;
			print $record->{_id}."\n";
			delete $record->{bag};
			$self->_dbout->save($record);
		});
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

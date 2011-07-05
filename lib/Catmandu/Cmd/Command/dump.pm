package Catmandu::Cmd::Command::dump;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
use Catmandu::Store::Simple;
use Data::Dumper;

has db => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]",
    required => 1
);
has id => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'r',
    documentation => "id [required]",
    required => 1
);
has _db => (
	is => 'ro',
	isa => 'Ref',
	lazy => 1,
	default => sub {
		Catmandu::Store::Simple->new(%{shift->db});
	}
);

sub execute{
        my($self,$opts,$args)=@_;
	#databank
	my $record = $self->_db->load($self->id);
	print Dumper($record) if defined($record);
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

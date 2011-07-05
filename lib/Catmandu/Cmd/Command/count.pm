package Catmandu::Cmd::Command::count;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
use Catmandu::Store::Simple;

has dbin => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]",
        required => 1
);
has _dbin => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		Catmandu::Store::Simple->new(%{shift->dbin});
	}
);
sub execute{
        my($self,$opts,$args)=@_;
	my $sth = $self->_dbin->_dbh->prepare("select count(*) from objects");
	$sth->execute;
	my $count = $sth->fetchrow;
	print "$count\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

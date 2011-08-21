package Catmandu::Cmd::Command::count;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
with qw(Catmandu::Cmd::Opts::Grim::Store);

has _store => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                my $class = "Catmandu::Store::Simple";
                Plack::Util::load_class($class);
                $class->new(%{$self->store_arg});
        }
);

sub execute{
        my($self,$opts,$args)=@_;
	my $sth = $self->_store->_dbh->prepare("select count(*) from objects");
	$sth->execute;
	my $count = $sth->fetchrow;
	print "$count\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

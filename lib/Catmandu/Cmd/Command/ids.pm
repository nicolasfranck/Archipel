package Catmandu::Cmd::Command::ids;
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
	$self->_store->each(sub{
                print shift->{_id}."\n";
        });
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

package Catmandu::Cmd::Command::dump;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
use Data::Dumper;
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
has id => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'r',
    documentation => "id [required]",
    required => 1
);

sub execute{
        my($self,$opts,$args)=@_;
	#databank
	my $record = $self->_store->load($self->id);
	print Dumper($record) if defined($record);
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

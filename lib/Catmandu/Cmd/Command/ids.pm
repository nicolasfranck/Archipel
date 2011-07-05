package Catmandu::Cmd::Command::ids;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando

has storetype => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 's',
    documentation => "Type of store [default:Simple]",
        default => sub{"Simple";}
);

has db_args => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]",
        required => 1
);

sub execute{
        my($self,$opts,$args)=@_;

	#databank
	my $class = "Catmandu::Store::".$self->storetype;
        Plack::Util::load_class($class) or die();
        my $store = $class->new(%{$self->db_args});
	$store->each(sub{
                print shift->{_id}."\n";
        });
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

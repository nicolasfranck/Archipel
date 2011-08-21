package Catmandu::Cmd::Opts::Grim::Harvester;
our $VERSION = 0.01;# VERSION
use Moose::Role;
use Net::OAI::Harvester;

has harvester_arg => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    required => 1,
    cmd_aliases => 'h',
    documentation => "Pass params to the harvester constructor.",
);
has _harvester => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                Net::OAI::Harvester->new(%{shift->harvester_arg});
        }
);

no Moose::Role;
1;

package Catmandu::Cmd::Opts::Grim::Store;
our $VERSION = 0.01;# VERSION
use Moose::Role;

has store_arg => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    required => 1,
    cmd_aliases => 's',
    documentation => "Pass params to the store constructor.",
);

no Moose::Role;
1;

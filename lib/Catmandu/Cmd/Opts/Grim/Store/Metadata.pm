package Catmandu::Cmd::Opts::Grim::Store::Metadata;
our $VERSION = 0.01;# VERSION
use Moose::Role;

has metadata_arg => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'metadata',
    documentation => "Metadata database (a) [required]",
    required => 1
);

no Moose::Role;
1;

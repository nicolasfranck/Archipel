package Catmandu::Cmd::Opts::Grim::Store::Merge;
our $VERSION = 0.01;# VERSION
use Moose::Role;

has skip => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Bool',
    cmd_aliases => 'skip',
    documentation => "Skip entries, when not present in both databases",
    required => 0,
    default => sub{0}
);

no Moose::Role;
1;

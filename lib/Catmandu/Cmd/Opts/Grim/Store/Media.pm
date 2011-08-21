package Catmandu::Cmd::Opts::Grim::Store::Media;
our $VERSION = 0.01;# VERSION
use Moose::Role;

has media_arg => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'media',
    documentation => "Media database (a) [required]",
    required => 1
);

no Moose::Role;
1;

package Catmandu::Cmd::Opts::Grim::Index::Solr;
our $VERSION = 0.01;# VERSION
use Moose::Role;

has index_arg => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    cmd_aliases => 't',
    default => sub { {url=>"http://localhost:8983/solr",id_field=>"id"} },
    documentation => "Pass params to the index constructor.",
);

no Moose::Role;
1;

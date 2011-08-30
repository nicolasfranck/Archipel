#!/usr/bin/env perl
use strict;
BEGIN {
	push @INC,$ENV{HOME}."/Catmandu/lib";
}
use Catmandu::Index::Solr;

my $index = Catmandu::Index::Solr->new(url=>"http://localhost:8983/solr/core0",id_field=>"id");
$index->commit;
$index->optimize;

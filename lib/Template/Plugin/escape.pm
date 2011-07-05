package Template::Plugin::escape;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
our $DYNAMIC = 1;

use strict;
use utf8;

sub filter {
    my ($self,$text) = @_;
	$text =~ s/(['"])/\\$1/g;
	$text;
}

1;

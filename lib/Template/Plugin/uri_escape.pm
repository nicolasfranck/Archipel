package Template::Plugin::uri_escape;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
our $DYNAMIC = 1;

use strict;
use utf8;
use URI::Escape;

sub filter {
 	my ($self,$text) = @_;
	return uri_escape($text);
}

1;

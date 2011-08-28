package Query::Fix::Simple;
use strict;
use utf8;
use parent qw(Query::Fix);

sub fix{
	my($self,$params)=@_;
	my $q = $params->{q} || "";
	#$q = $self->double_quotes($q);
	$q = $self->fix_id($q);
	return $q;
}

1;

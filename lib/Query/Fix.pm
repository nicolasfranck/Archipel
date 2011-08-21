package Query::Fix;
use strict;
use utf8;

sub new {
	bless{},shift;
}
sub double_quotes {
	my($self,$value)=@_;
	$value =~ s/^'/"/;
	$value =~ s/'$/"/;
	return $value;
}
sub escape{
	my($self,$value)=@_;
	$value =~ s/([^\\])([\'\"])/$1\\$2/g;
	return $value;
}
sub fix_id {
	my($self,$value)=@_;
	$value = "\"$value\"" if $value =~ /^rug\d{2}:\d{9}$/;
	return $value;
}

1;

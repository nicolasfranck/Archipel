package Query::Fix;
use utf8;
use Text::Unaccent::PurePerl;
use Hash::MultiValue;

sub new {
	bless{},shift;
}
sub unaccent{
        my($self,$value)=@_;
        $value = "" if not defined($value);
        $value = unac_string("UTF8",$value);
	return $value;
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

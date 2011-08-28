package Template::Plugin::Quote;
use parent qw(Template::Plugin);

sub new {
	my ($class, $context) = @_;
	$context->define_vmethod($_, escape_quotes => \&escape_quotes ) for qw(scalar);
	bless {}, $class;
}
sub escape_quotes {
	$_[0] =~ s/('|")/\\$1/g;# ' => \' en " => \"
        return $_[0];
}

1;

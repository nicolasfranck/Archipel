package Template::Plugin::clean_query;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
our $DYNAMIC = 1;

use strict;
use utf8;
use Text::Unaccent::PurePerl;
use Encode;

sub unaccent {
        my($self,$oct) = @_;
        encode("utf8", unac_string($oct));
}
sub clean{
	my($self,$value,$key)=@_;
	print "test!!\n";
	$value = "" if not defined($value);		
	$value =~ s/['"]/ /g;
	$value =~ s/[\s]+/_/g;#compacteren
	$value = $self->unaccent($value);#accenten verwijderen
	$value = lc($value);#lowercase
	$value =~ s/[^a-z0-9_-]//g;#eenmaal accenten verwijderd (vb. é -> e), mogen niet alphanumerieke karakters eruit
	my %seen;
	my @content = grep !($seen{$_}++), split( /_/, $value );#enkel unieke waarden mogen overblijven -> vb. belgie belgie -> belgie
	my $output = join '+',map {"$key:$_"} @content;
	return $output;
}

1;

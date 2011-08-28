package Template::Plugin::Aleph;
use parent qw(Template::Plugin);
use Data::Dumper;

my $filter_mapping = {
	title => "filter_title",
	author => "filter_author"
};
sub new {
	my ($class, $context) = @_;
	$context->define_vmethod($_, to_external_query => sub {
		my($val,$key,$opts)=@_;
		return "" if !defined($filter_mapping->{$key});
		my $sub = "filter_${key}";
		$val = &$sub($val,$opts);
		return $val;
	}) for qw(scalar);
	bless {}, $class;
}
sub filter_title {
	my($title,$opts) = @_;
	#<a> : <b> / <c> [<h>] -> <a> <b>
	$title =~ s/\[.*\]$//g;
	$title =~ s/\/.*$//g;
	$title =~ s/://g;
	finish($title,$opts);
}
sub filter_author {
	my($author,$opts) = @_;
	#achternaam, voornaam, datum. -> achternaam voornaam
	finish($author,$opts);
}
sub finish {
	my($val,$opts) = @_;
	$opts{minlength} ||=0;
	#lowercase
	$val = lc($val);
	#punctuatie verwijderen
        $val =~ s/[[:punct:]]//g;
	#aanhalingstekens verwijderen
        $val =~ s/('|")//g;
	#alle decimalen en wat daaraan vasthangt verwijderen
        $val =~ s/\d+\w+//g;
        $val =~ s/\w+\d+//g;
        $val =~ s/\d+//g;
	#teveel aan witte ruimte-tekens verwijderen
        $val =~ s/\s\s+/ /g;
        $val =~ s/^\s//g;
        $val =~ s/\s$//g;
        my @values = split(' ',$val);
	my @newvalues = ();
	#duplicaten+minimum lengte
	my %uniq = ();
	foreach(@values){
		if(length($_)>$opts->{minlength}){
			if(!$unique{$_}){
				push @newvalues,$_;
				$unique{$_}=1;
			}
		}
	}
	#aantal
	$opts->{num} = ($opts->{num} && $opts->{num} > 1)? $opts->{num}:scalar(@newvalues);
	splice(@newvalues,$opts->{num});
        return join(' ',@newvalues);
}

1;

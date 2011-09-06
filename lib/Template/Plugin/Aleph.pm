package Template::Plugin::Aleph;
use strict;
use parent qw(Template::Plugin);

my $filter_mapping = {
	title => \&filter_title,
	author => \&filter_author
};
sub new {
	my ($class, $context) = @_;
	$context->define_vmethod($_, to_external_query => sub {
		my($val,$key,$opts)=@_;
		my $sub = $filter_mapping->{$key};
		return "" if !defined($sub);
		$val = $sub->($val,$opts);
		return $val;
	}) for qw(scalar);
	bless {}, $class;
}
sub filter_title {
	my($title,$opts) = @_;
	#<a> : <b> / <c> [<h>] -> <a> <b>
	$title =~s/\[[^\[\]]*?\]$//;
        $title =~ s/\/.*$//;
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
	$opts->{minlength} ||=0;
        #lowercase
        $val = lc($val);
        #punctuatie verwijderen
        $val =~ s/[[:punct:]]/ /g;
        #aanhalingstekens verwijderen
        $val =~ s/('|")/ /g;
        #teveel aan witte ruimte-tekens verwijderen
        $val =~ s/\s\s+/ /g;
        $val =~ s/^\s//g;
        $val =~ s/\s$//g;
        my @values = split(' ',$val);
        my @newvalues = ();
        #duplicaten+minimum lengte
        my %unique = ();
        foreach(@values){
                if(length($_)>=$opts->{minlength}){
                        if(!defined($unique{$_})){
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

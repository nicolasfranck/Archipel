package Query::Fix::Advanced;
use strict;
use utf8;
use parent qw(Query::Fix);

sub fix{
        my($self,$params)=@_;

        my $search_and = $params->{search_and};
        my $search_or = $params->{search_or};
        my $search_exact = $params->{search_exact};
        my $search_negative = $params->{search_negative};
	my $context = $params->{context};

	#alle woorden
        my $str_and;
        if(defined($search_and) && $search_and ne ""){
        	$str_and = "(".join(' AND ',map {$self->fix_id($_)} map {$self->double_quotes($_)} split /\s+/,$search_and).")";
        }
        #sommige woorden
        my $str_or;
        if(defined($search_or) && $search_or ne ""){
                $str_or = "(".join(' OR ',map {$self->fix_id($_)} map {$self->double_quotes($_)} split /\s+/,$search_or).")";
        }
        #exacte combinatie
        my $str_exact;
        if(defined($search_exact)&& $search_exact ne ""){
                $str_exact = "(\"$search_exact\")";
        }
        #negative selectie
        my $str_negative;
        if(defined($search_negative) && $search_negative ne ""){
                $str_negative = "-(".join(' OR ',map {$self->fix_id($_)} map {$self->double_quotes($_)} split /\s+/,$search_negative).")";
        }
        my $q = join(' AND ',grep {defined($_) && $_ ne ""} ($str_and,$str_or,$str_exact,$str_negative));
	#context
        if(defined($context) && $context ne ""){
                $q="$q AND (context:$context)";
        }
	return $q;
}

1;

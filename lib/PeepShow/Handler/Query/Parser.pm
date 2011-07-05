package PeepShow::Handler::Query::Parser;
use Catmandu;
use PeepShow::Handler::Query::Fixer;
use List::MoreUtils qw(first_index);

sub new {
	bless {
		_query_fixer => PeepShow::Handler::Query::Fixer->new(),
		_sort_fields => Catmandu->conf->{DB}->{index}->{sort_fields},
		error => undef
	},shift;
}
sub _query_fixer {
	shift->{_query_fixer};
}
sub _sort_fields {
	shift->{_sort_fields};
}
sub error {
	my $self = shift;
	if(@_){$self->{error}=shift;}
	$self->{error};
}	
sub has_error {
	shift->error;
}

sub parse {
	my($self,$params)=@_;
	$self->error(undef);
	#q en opts zijn de return-waarden
	my $opts = {};
	#conf
	my $maxresults= Catmandu->conf->{DB}->{index}->{maxresults};
        my $num_default = Catmandu->conf->{DB}->{index}->{num_default};
        my $pages_per_set = Catmandu->conf->{DB}->{index}->{pages_per_set};
	
	#params
	my $q = $self->_query_fixer->handle($params);
	$params->{q}=$q;
        my $display = $params->{display};
        my $sort = $params->{sort};
        my $sort_dir = $params->{sort_dir};
	my $start = $params->{start};

	#sortering
        $sort = "" if not defined($sort);
        my $sort_available = first_index {$_ eq $sort} @{$self->_sort_fields};
	if($sort_available == -1){
		$sort = undef;
	}elsif($sort eq "score" || $sort eq ""){
                $sort="score";
        }
        $sort_dir = (defined($sort_dir) && ($sort_dir eq "asc" || $sort_dir eq "desc"))? $sort_dir:"asc";
	if(defined($q) && $q ne ""){
		if(defined($display) && $display eq "prevnext"){
                        $start = ($start && int($start) >= 0)? int($start) :0;
                        $opts->{start} = $start;
			$opts->{limit} = 1;
                        $opts->{sort}="$sort $sort_dir" if defined($sort);
			$params->{num}=1;
		}else{
			$params->{num} = $params->{num} || $num_default;
                        $params->{num} = $params->{num} > $maxresults ? $maxresults:$params->{num};
                        $params->{page} = ($params->{page} && $params->{page} > 0 && $params->{page} =~ /^\d+$/)? $params->{page} : 1;
                        $start = ($params->{page} - 1)*$params->{num};
                       	$opts->{start} = $start;
			$opts->{limit} = $params->{num};
			$opts->{'facet'}='true';
			$opts->{'facet.field'}='context';
                        $opts->{sort}="$sort $sort_dir" if defined($sort);
		}
	}else{
		$self->error("no query");
	}
	return $q,$opts;
	
}

1;

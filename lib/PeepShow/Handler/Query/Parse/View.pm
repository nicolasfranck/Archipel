package PeepShow::Handler::Query::Parse::View;
use parent qw(PeepShow::Handler::Query::Parse);

sub parse{
	my($self,$params)=@_;
	$self->error(undef);
        #q en opts zijn de return-waarden
	my $opts = {};
	#parameters afkomstig van Moose::Role
	my $q = $self->fix_query($params);
	if(not defined($q) || $q eq ""){
		$self->error("no query");	
		return $q,$opts;
	}
	my $sort = $self->sort($params);
	my $sort_dir = $self->sort_dir($params);
	#eigen parameters
	my $start = $params->{start};
	#berekening
	$start = ($start && int($start) >= 0)? int($start) :0;
        $opts->{start} = $start;
        $opts->{limit} = 1;
        $opts->{sort}="$sort $sort_dir" if defined($sort);
	return $q,$opts;
}

1;

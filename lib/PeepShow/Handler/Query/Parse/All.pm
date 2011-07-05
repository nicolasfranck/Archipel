package PeepShow::Handler::Query::Parse::All;
use Catmandu;
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
	my $num = $self->num($params);
	my $page = $self->page($params);
	#berekening
	my $start = ($page - 1)*$num;
        $opts->{start} = $start;
        $opts->{limit} = $num;
        $opts->{'facet'}='true';
        $opts->{'facet.field'}='context';
	$opts->{'spellcheck'}='true';
        $opts->{sort}="$sort $sort_dir" if defined($sort);
	return $q,$opts;
}

1;

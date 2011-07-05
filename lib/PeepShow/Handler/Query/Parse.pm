package PeepShow::Handler::Query::Parse;
use Catmandu;
use Query::Fix::Simple;
use Query::Fix::Advanced;
use List::MoreUtils qw(first_index);
use Text::Glob qw(glob_to_regex);

sub new {
	bless {
		_query_fix_simple => Query::Fix::Simple->new(),
		_query_fix_advanced => Query::Fix::Advanced->new(),
		_sort_fields => Catmandu->conf->{DB}->{index}->{sort_fields} || [],
		error => undef,
		_allowed => glob_to_regex(Catmandu->conf->{allowed})
	},shift;
}
sub _query_fix_simple {
	shift->{_query_fix_simple};
}
sub _query_fix_advanced {
        shift->{_query_fix_advanced};
}
sub _sort_fields {
        shift->{_sort_fields};
}
sub error {
        my $self = shift;
        if(@_){$self->{error}=shift;}
        $self->{error};
}
sub _allowed {
	shift->{_allowed};
}
sub fix_simple_query {
	shift->_query_fix_simple->fix(shift);
}
sub fix_advanced_query {
        shift->_query_fix_advanced->fix(shift);
}
sub fix_query {
	my($self,$params)=@_;
	my $t = $params->{search_type};
	(defined($t) && $t eq "advanced")? $self->fix_advanced_query($params):$self->fix_simple_query($params);
}
sub sort {
	my($self,$params)=@_;
	my $sort = $params->{sort};
	$sort = "" if not defined($sort);
        my $sort_available = first_index {$_ eq $sort} @{$self->_sort_fields};
        if($sort_available == -1){
                $sort = undef;
        }elsif($sort eq "score" || $sort eq ""){
                $sort="score";
        }
	return $sort;
}
sub sort_dir {
	my($self,$params)=@_;
	my $sort_dir = $params->{sort_dir};
	$sort_dir = (defined($sort_dir) && ($sort_dir eq "asc" || $sort_dir eq "desc"))? $sort_dir:"asc";
	return $sort_dir;
}
sub has_error {
        shift->error;
}
sub is_local {
	my($self,$sourceIP)=@_;
	$sourceIP =~ $self->_allowed;
}
sub num {
        my($self,$params)=@_;
	my $maxresults= Catmandu->conf->{DB}->{index}->{maxresults};
	my $num_default = Catmandu->conf->{DB}->{index}->{num_default};
	$params->{num} = $params->{num} || $num_default;
	$params->{num} = $params->{num} > $maxresults ? $maxresults:$params->{num};
	return $params->{num};
}
sub page {
	my($self,$params)=@_;
	$params->{page} = ($params->{page} && $params->{page} > 0 && $params->{page} =~ /^\d+$/)? $params->{page} : 1;
	return $params->{page};
}

1;

package PeepShow::Handler::Query::Parse;
use strict;
use utf8;
use Catmandu;
use Query::Fix::Simple;
use Query::Fix::Advanced;
use List::MoreUtils qw(first_index);
use Text::Glob qw(glob_to_regex);

sub new {
	bless {
		_query_fix_simple => Query::Fix::Simple->new(),
		_query_fix_advanced => Query::Fix::Advanced->new(),
		_sort_fields => Catmandu->conf->{app}->{search}->{sort_fields} || [],
		error => undef,
		_allowed => glob_to_regex(Catmandu->conf->{all}->{allowed_range})
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
	$params->add(sort=>$sort);
	return $params->{sort};
}
sub sort_dir {
	my($self,$params)=@_;
	my $sort_dir = $params->{sort_dir};
	$sort_dir = (defined($sort_dir) && ($sort_dir eq "asc" || $sort_dir eq "desc"))? $sort_dir:"asc";
	$params->add(sort_dir=>$sort_dir);
	return $params->{sort_dir};
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
	my $maxresults= Catmandu->conf->{app}->{search}->{max_results};
	my $num_default = Catmandu->conf->{app}->{search}->{num_default};
	my $num = $params->{num};
	$num = $num || $num_default;
	$num = $num > $maxresults ? $maxresults:$num;
	$params->add(num => $num);
	return $params->{num};
}
sub page {
	my($self,$params)=@_;
	my $page = ($params->{page} && $params->{page} > 0 && $params->{page} =~ /^\d+$/)? $params->{page} : 1;
	$params->add(page => $page);
	return $params->{page};
}

1;

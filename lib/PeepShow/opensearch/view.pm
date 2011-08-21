package PeepShow::opensearch::view;
use Catmandu::App;

use parent qw(PeepShow::App::Common PeepShow::App::Search);

use PeepShow::Handler::Query::Parse::View;
use PeepShow::Handler::Record::View;
use PeepShow::Handler::Query::Register;
use PeepShow::Tools::Record;
use Data::Pageset;

any([qw(get post)],'',sub{
	my $self = shift;
	#conf
 	my $pages_per_set = Catmandu->conf->{app}->{search}->{pages_per_set};
	#params
	my $params = $self->request->parameters;
	$params->add(view => "pages");
	my $sess = $self->request->session;
	my $cols = int($params->{cols} || 2);
	$cols = ($cols > 5)? 5:$cols;
	$params->add(cols=>$cols);
	my($q,$opts)=$self->query_parser->parse($params);
	$params->add(q=>$q);
	if(!$self->query_parser->has_error){
		my($hits,$totalhits,$err)=$self->db->query_store($q,%$opts);
		if(!defined($err) && @$hits > 0){
			for(my $i=0;$i<scalar(@$hits);$i++){
                        	$hits->[$i]->{id}=$hits->[$i]->{_id};
			}
			my $hash = $self->query_register->inspect($params,!$self->query_parser->has_error);
			$self->store_sess($hash->{sess});
			$self->store_param($hash->{params});
			my $args = {};
			$args->{first} = 0;
                        $args->{last} = $totalhits - 1;
                        $args->{prev} = ($opts->{start} > 0) ? $opts->{start} - 1:undef;
                        $args->{next} = ($totalhits - 1 > $opts->{start})? $opts->{start} + 1:undef;
                        $args->{total_hits}=$totalhits;
                        $args->{start}=$opts->{start};
			$params->add(start => $opts->{start});
			$args->{hit} = $hits->[0];
			$args->{total_items} = scalar(@{$hits->[0]->{media}});
		
			my $page_args = $self->page_args;
			$page_args->{args} = {%{$page_args->{args}},%$args};
			my $res = $self->record_view->handle($page_args);
			if(!$res->{err}){
				$self->print_template($self->template('opensearch_view'),$page_args);
			}
		}
	}
});

sub query_parser {
	shift->stash->{query_parser}||=PeepShow::Handler::Query::Parse::View->new();
}
sub query_register {
	shift->stash->{query_register} ||= PeepShow::Handler::Query::Register->new();
}
sub record_view{
        my $self = shift;
        $self->stash->{record_view}||=PeepShow::Handler::Record::View->new();
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

package PeepShow::opensearch;
use Catmandu::App;

use parent qw(PeepShow::App::Common PeepShow::App::Search);

use PeepShow::Handler::Query::Parse::All;
use PeepShow::Handler::Query::Register;
use PeepShow::Tools::Record;
use Data::Pageset;

any([qw(get post)],'',sub{
	
	my $self = shift;
	#conf
	my $pages_per_set = Catmandu->conf->{app}->{search}->{pages_per_set};
	#params
	my $params = $self->request->parameters;
	my $sess = $self->request->session;
	my $cols = int($params->{cols} || 2);
	$cols = ($cols > 5)? 5:$cols;
	$params->add(cols=>$cols);
	delete $params->{start};
	delete $params->{display};
	my($q,$opts)=$self->query_parser->parse($params);
	$params->add(q=>$q);
	if(!$self->query_parser->has_error){
		my($hits,$totalhits,$err)=$self->db->query_store($q,%$opts);
		if(!defined($err) && $totalhits > 0){
			for(my $i=0;$i<scalar(@$hits);$i++){
                        	$hits->[$i]->{id}=$hits->[$i]->{_id};
			}
			my $hash = $self->query_register->inspect($params,!$self->query_parser->has_error);
			$self->store_sess($hash->{sess});
			$self->store_param($hash->{params});
			my $page_info = Data::Pageset->new({
	                    'total_entries'       => $totalhits,
	                    'entries_per_page'    => $params->{num},
	                    'current_page'        => $params->{page},
	                    'pages_per_set'       => $pages_per_set,
	                    'mode'                => 'fixed'
	                });

	                #alles geïnitialiseerd? -> verzamel alles
	                my $page_args = $self->page_args;
	                my $args = {
				s => $page_args->{params}->{sort},
	                        hits => $hits,
	                        total_hits => $totalhits,
	                        begin_item => $opts->{start}+1,
	                        end_item => $opts->{start}+scalar(@$hits),
	                        first_page => $page_info->first_page,
	                        last_page => $page_info->last_page,
	                        previous_page => $page_info->previous_page,
	                        next_page => $page_info->next_page,
	                        pages_in_set => $page_info->pages_in_set,
	                        current_page => $page_info->current_page,
	                };
			$page_args->{args} = {%{$page_args->{args}},%$args};
			$self->print_template($self->template('opensearch'),$page_args);
		}
	}
});
sub query_parser {
	shift->stash->{query_parser}||=PeepShow::Handler::Query::Parse::All->new();
}
sub query_register {
	shift->stash->{query_register} ||= PeepShow::Handler::Query::Register->new();
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

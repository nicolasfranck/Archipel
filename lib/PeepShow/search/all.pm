package PeepShow::search::all;
use Catmandu::App;
use Plack::Util;

use parent qw(PeepShow::App::Common PeepShow::App::Search);

use PeepShow::Handler::Query::Parse::All;
use PeepShow::Handler::Record::View;
use PeepShow::Handler::Query::Register;
use PeepShow::Tools::Record;
use Data::Pageset;
use RestFields::Fixer;

any([qw(get post)],'/',sub{
	my $self = shift;

	#parameters
	my $params = $self->request->parameters;
	
	if(!defined($params->{q}) && !defined($params->{search_type})){
		$self->home;
		return;
	}else{
		#conf
		my $pages_per_set = Catmandu->conf->{app}->{search}->{pages_per_set};
		#parse
		my($q,$opts)=$self->query_parser->parse($params);
		$params->add(q=>$q);
		my $hash = {};
		if(!$self->query_parser->has_error){	
			#alles ok? Dan kijken in het configuratiebestand of we parameters moeten opslaan (reset parameters of in sessie)
			$hash = $self->query_register->inspect($params,!$self->query_parser->has_error);
			#+pas query toe
			my($hits,$totalhits,$err,$rest_fields)=$self->db->query_store($q,%$opts);
			
			my $rest = $self->restfield_fixer->fix($rest_fields);
			if(!defined($err) && $totalhits > 0){
				$self->store_sess($hash->{sess});
				$self->store_param($hash->{params});
				#toon hits, in overzicht
				for(my $i=0;$i<scalar(@$hits);$i++){
					$hits->[$i]->{id}=$hits->[$i]->{_id};
					$hits->[$i]->{numitems}=scalar(@{$hits->[$i]->{media}});
					$hits->[$i]->{media}=slice($hits->[$i]->{media},0,1);
				}
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
					hits => $hits,		
					restfields => $rest,
					total_hits => $totalhits,
					begin_item => $opts->{start}+1,
					end_item => $opts->{start}+scalar(@$hits),#en niet:totalhits, want die kan er boven of er onder liggen!
					first_page => $page_info->first_page,
					last_page => $page_info->last_page,
					previous_page => $page_info->previous_page,
					next_page => $page_info->next_page,
					pages_in_set => $page_info->pages_in_set,
					current_page => $page_info->current_page,
				};
				$page_args->{args} = {%{$page_args->{args}},%$args};
				$self->print_template($self->template('search'),$page_args);
			}else{
				my $page_args = $self->page_args;
				my $args = {
					errmsg => "no results",
					restfields => $rest
				};
				$page_args->{args} = {%{$page_args->{args}},%$args};
				$self->print_template($self->template('search'),$page_args);
			}
		}else{
			my $page_args = $self->page_args;
			my $args = {errmsg => $self->query_parser->error};
			$page_args->{args} = {%{$page_args->{args}},%$args};
			$self->print_template($self->template('search'),$page_args);
		}
	}
});
sub home {
        my $self = shift;
        my $page_args = $self->page_args;
	my $args = {
		columns => $self->load_columns,
	};
	$page_args->{args} = {%{$page_args->{args}},%$args};
        $self->print_template($self->template('home'),$page_args);
}
sub load_columns {
        my $self = shift;
        my $columns = [];
        $self->columns->each(sub{
                push @$columns,shift;
        });
        [sort {$a->{added} <=> $b->{added}} @$columns];
}
sub load_package {
        my($self,$package,$args) = @_;
        $self->stash->{$package} ||= Plack::Util::load_class($package);
        if($args){return $package->new(%$args);}
        else {return $package->new();}
}
sub columns {
        my $self = shift;
        $self->stash->{columns} ||= $self->load_package(Catmandu->conf->{database}->{columns}->{class},Catmandu->conf->{database}->{columns}->{args});
}
sub query_parser {
	shift->stash->{query_parser}||=PeepShow::Handler::Query::Parse::All->new();
}
sub query_register {
	shift->stash->{query_register} ||= PeepShow::Handler::Query::Register->new();
}
sub restfield_fixer {
	shift->stash->{restfield_fixer} ||= RestFields::Fixer->new;
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

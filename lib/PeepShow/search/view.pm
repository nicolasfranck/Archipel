package PeepShow::search::view;
use Catmandu::App;

use parent qw(PeepShow::App::Common PeepShow::App::Search);

use PeepShow::Handler::Query::Parse::View;
use PeepShow::Handler::Query::Register;
use PeepShow::Handler::Record::View;
use PeepShow::Tools::Record;
use Data::Pageset;
use List::MoreUtils qw(first_index);
use Try::Tiny;

any([qw(get post)],'',sub{
	my $self = shift;
	#conf
	my $pages_per_set = Catmandu->conf->{app}->{search}->{pages_per_set};
	#parameters (add hoc)
	my $params = $self->request->parameters;
	my $display = $params->{display};
	#parse
	my($q,$opts)=$self->query_parser->parse($params);
	$params->add(q=>$q);
	my $hash = {};
	if(!$self->query_parser->has_error){
		$hash = $self->query_register->inspect($params,!$self->query_parser->has_error);
	}
	#pas query toe
	if(!$self->query_parser->has_error){	
		my($hits,$totalhits,$err,$rest_fields)=$self->db->query_store($q,%$opts);
		if(!defined($err) && scalar(@$hits) > 0){
			$self->store_sess($hash->{sess});
			$self->store_param($hash->{params});
			#alles geïnitialiseerd? -> verzamel alle pagina-argumenten (parameters,configuratie en sessie)
			my $args = {};
			$args->{hit} = $hits->[0];
			$args->{first} = 0;
			$args->{last} = $totalhits - 1;
			$args->{prev} = ($opts->{start} > 0) ? $opts->{start} - 1:undef;
			$args->{next} = ($totalhits - 1 > $opts->{start})? $opts->{start} + 1:undef;
			$args->{total_hits}=$totalhits;
			$args->{start}=$opts->{start};
			$args->{s} = $params->{sort};
			$params->add(start=>$opts->{start});
			my $view = $params->{view};
			$view = (defined($view) && defined(Catmandu->conf->{package}->{Record}->{View}->{$view}))? $view:Catmandu->conf->{package}->{Record}->{View}->{default};
			$params->add(view=>$view);
			#security check
			if(defined($params->{view}) && $params->{view} eq "carousel"){	
				my $poster_item_id = $hits->[0]->{poster_item_id};
				my $has_carousel = ((first_index {$_ eq "carousel"} @{$hits->[0]->{media}->[$poster_item_id - 1]->{services}}) > -1 );
				if(!$has_carousel){
					$params->add( view => "record");
				}elsif(!$self->is_local && !$hits->[0]->{access}->{services}->{carousel}){
					$params->add(view => "record");
				}
			}
			$args->{captcha_html} = $self->captcha_html;
			my $page_args = $self->page_args;
			$page_args->{args}->{is_local} = $self->is_local;
			$page_args->{args} = {%{$page_args->{args}},%$args};
			$self->print_record($page_args);					
		}else{
			my $page_args = $self->page_args;
	                my $args = {errmsg => "no results"};
			$page_args->{args} = {%{$page_args->{args}},%$args};
        	        $self->print_template($self->template('search'),$page_args);
		}
	}else{
		my $page_args = $self->page_args;
                my $args = {errmsg => $self->query_parser->error};
		$page_args->{args} = {%{$page_args->{args}},%$args};
                $self->print_template($self->template('search'),$page_args);
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

sub print_record{
	my($self,$page_args)=@_;
	my $res = $self->record_view->handle($page_args);
	my $template = $res->{err} ? $self->template('record_simple'):$self->template("record_".$res->{template_key});
	$self->print_template($template,$page_args);			
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

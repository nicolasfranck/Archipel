package PeepShow::search_view;
use Catmandu::App;
use Plack::Util;
use PeepShow::Handler::Query::Parse::View;
use PeepShow::Handler::Query::Register;
use PeepShow::Handler::Record::View;
use PeepShow::Tools::Record;
use Data::Pageset;
use PeepShow::Resolver::DB;
use Text::Glob qw(glob_to_regex);
use List::MoreUtils qw(first_index);

any([qw(get post)],'',sub{
	my $self = shift;
	#conf
	my $pages_per_set = Catmandu->conf->{DB}->{index}->{pages_per_set};
	#parameters (add hoc)
	my $params = $self->request->parameters;
	my $display = $params->{display};
	#parse
	my($q,$opts)=$self->query_parser->parse($params);
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
			$args->{first} = 0;
			$args->{last} = $totalhits - 1;
			$args->{prev} = ($opts->{start} > 0) ? $opts->{start} - 1:undef;
			$args->{next} = ($totalhits - 1 > $opts->{start})? $opts->{start} + 1:undef;
			$args->{total_hits}=$totalhits;
			$args->{start}=$opts->{start};
			#security check
			if(defined($params->{view}) && $params->{view} eq "carousel"){	
				my $poster_item_id = $hits->[0]->{poster_item_id};
				my $has_carousel = ((first_index {$_ eq "carousel"} @{$hits->[0]->{media}->[$poster_item_id - 1]->{services}}) > -1 );
				if(!$has_carousel){
					$params->{view} = "record";
				}elsif(!$self->is_local && !$hits->[0]->{access}->{services}->{carousel}){
					$params->{view} = "record";
				}
			}
			$self->print_record({
				record => $hits->[0],
				view => $params->{view},
				sess => $self->request->session,
				params => $self->request->parameters,
				conf => $self->conf_common,
				args => $args
			});					
		}else{
			my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
	                $page_args_common->{errmsg} = "no results";
        	        $self->print_template($self->template('search'),$page_args_common);
		}
	}else{
		my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
                $page_args_common->{errmsg} = $self->query_parser->error;
                $self->print_template($self->template('search'),$page_args_common);
	}
});
sub sourceIP {
        my $self = shift;
        my $sourceIP = $self->env->{HTTP_X_FORWARDED_FOR} ? $self->env->{HTTP_X_FORWARDED_FOR} : $self->env->{REMOTE_ADDR};
        my @ips = split(',',$sourceIP);
        $sourceIP = pop @ips;
        return $sourceIP;
}
sub allowed_range {
        my $self = shift;
        Catmandu->stash->{allowed_range} ||= glob_to_regex(Catmandu->conf->{allowed_range});
}
sub is_local {
        my $self = shift;
        my $return = ($self->sourceIP =~ $self->allowed_range)? 1:0;
	return $return;
}
sub query_parser {
	shift->stash->{query_parser}||=PeepShow::Handler::Query::Parse::View->new();
}
sub query_register {
	shift->stash->{query_register} ||= PeepShow::Handler::Query::Register->new();	
}
sub db{
	my $self = shift;
	$self->stash->{db}||=PeepShow::Resolver::DB->new();
}
sub store_sess{
	my($self,$hash)=@_;
	$self->request->session->{$_}=$hash->{$_} foreach(keys %$hash);
}
sub store_param{
        my($self,$hash)=@_;
        $self->request->parameters->{$_}=$hash->{$_} foreach(keys %$hash);
}
sub sess_common{
	my $self = shift;
	my $sess = $self->request->session;
	my %hash = map {("sess_$_" => $sess->{$_})} keys %$sess;
	return \%hash || {};
}
sub params_common{
	my $self = shift;
	#parameters
	my $params = $self->request->parameters || {};
}

sub conf_common{
	my $self = shift;
	my $language = $self->language;
	#configuratie-gegevens
	return{
		conf_metadata => Catmandu->conf->{Language}->{$language}->{Record},
		id_field => Catmandu->conf->{DB}->{index}->{args}->{id_field},
		service_order => Catmandu->conf->{ServiceOrder},
		rooturl => $self->rooturl,
		permroot => $self->permroot,
		request_uri => $self->env->{REQUEST_URI},
		conf_sorts => Catmandu->conf->{Language}->{$language}->{Record}->{sort_fields},
		openURL => $self->openURL
	};
}
sub template{
	my($self,$template) = @_;	
	my $language = $self->language;
	Catmandu->conf->{Language}->{$language}->{Templates}->{$template};
}
sub language{
	my $self = shift;
	my $language = $self->request->parameters->{language};
	$language = (defined($language) && defined(Catmandu->conf->{Language}->{$language}))? $language:Catmandu->conf->{Language}->{default};
}

sub page_args_common{
	my($self,$params_common,$sess_common,$conf_common)=@_;
	return{
		%$params_common,%$sess_common,%$conf_common
	};
}
sub rooturl{
	return Catmandu->conf->{rooturl};
}
sub openURL {
	Catmandu->conf->{openURL};
}
sub permroot {
        return Catmandu->conf->{permroot};
}
sub sort_fields{
	my $self = shift;
	return Catmandu->conf->{DB}->{index}->{sort_fields};
}

sub record_view{
	my $self = shift;
	$self->stash->{record_view}||=PeepShow::Handler::Record::View->new();
}

sub print_record{
	my($self,$opts)=@_;
	my $res = $self->record_view->handle($opts);
	if($res->{err}){
		my $page_args_common = $self->page_args_common(
			{%{$self->params_common},%{$res->{args}},is_local => $self->is_local},
			$self->sess_common,
			$self->conf_common
		);
		$self->print_template($self->template('record_simple'),$page_args_common);
	}else{
		my $page_args_common = $self->page_args_common(
                        {%{$self->params_common},%{$res->{args}},is_local => $self->is_local},
                        $self->sess_common,
                        $self->conf_common,
                );
		my $template = $self->template("record_".$res->{template_key});
		$self->print_template($template,$page_args_common);	
	}	
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

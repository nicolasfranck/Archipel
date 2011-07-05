package PeepShow::search_all;
use Catmandu::App;
use Plack::Util;
use PeepShow::Handler::Query::Parse::All;
use PeepShow::Handler::Record::View;
use PeepShow::Handler::Query::Register;
use PeepShow::Tools::Record;
use Data::Pageset;
use PeepShow::Resolver::DB;
use Text::Glob qw(glob_to_regex);
use RestFields::Fixer;

any([qw(get post)],'/',sub{
	my $self = shift;

	#parameters (add hoc)
	my $params = $self->request->parameters;
	
	if(!defined($params->{q}) && !defined($params->{search_type})){
		$self->home;
		return;
	}else{
		#conf
		my $pages_per_set = Catmandu->conf->{DB}->{index}->{pages_per_set};
		#parse
		my($q,$opts)=$self->query_parser->parse($params);
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
				my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
				my $new_args = {			
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
					q => $q,
					conf_context => Catmandu->conf->{Language}->{$self->language}->{Context}
				};
				$page_args_common = {%$page_args_common,%$new_args};	
				$self->print_template($self->template('search'),$page_args_common);
			}else{
				my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
				$page_args_common->{errmsg} = "no results";
				$page_args_common->{q}=$q;
				$page_args_common->{restfields} = $rest;
				$self->print_template($self->template('search'),$page_args_common);
			}
		}else{
			my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
			$page_args_common->{errmsg} = $self->query_parser->error;
			$self->print_template($self->template('search'),$page_args_common);
		}
	}
});
sub home {
        my $self = shift;
        my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
        $page_args_common->{columns}=$self->load_columns;
        $page_args_common->{language} = $self->language;
        $self->print_template($self->template('home'),$page_args_common);
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
        $self->stash->{columns} ||= $self->load_package(Catmandu->conf->{Columns}->{db}->{class},Catmandu->conf->{Columns}->{db}->{args});
}

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
	$self->sourceIP =~ $self->allowed_range;
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
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

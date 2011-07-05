package PeepShow::opensearch_view;
use Catmandu::App;
use Plack::Util;
use PeepShow::Handler::Query::Parse::View;
use PeepShow::Handler::Record::View;
use PeepShow::Handler::Query::Register;
use PeepShow::Tools::Record;
use Data::Pageset;
use PeepShow::Resolver::DB;
use Text::Glob qw(glob_to_regex);

any([qw(get post)],'',sub{
	my $self = shift;
	#conf
 	my $pages_per_set = Catmandu->conf->{DB}->{index}->{pages_per_set};
	#params
	my $params = $self->request->parameters;
	$params->{view} = "pages";
	my $sess = $self->request->session;
	my $cols = int($params->{cols} || 2);
	$cols = ($cols > 5)? 5:$cols;
	my($q,$opts)=$self->query_parser->parse($params);
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
			$args->{hits} = $hits;
			$args->{cols}=$cols;
			$args->{total_items} = scalar(@{$hits->[0]->{media}});
			my $res = $self->record_view->handle({
				record => $hits->[0],
                                view => $params->{view},
                                sess => $self->request->session,
                                params => $self->request->parameters,
                                conf => $self->conf_common,
                                args => $args	
			});
			if(!$res->{err}){
				my $page_args_common = $self->page_args_common(
					{%{$self->params_common},%{$res->{args}}},
					$self->sess_common,
					$self->conf_common
				);
				$self->print_template($self->template('opensearch_view'),$page_args_common);
			}
		}
	}
});

sub query_parser {
	shift->stash->{query_parser}||=PeepShow::Handler::Query::Parse::View->new();
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
	return \%hash;
}
sub params_common{
	my $self = shift;
	#parameters
	my $params = $self->request->parameters;
}

sub conf_common{
	my $self = shift;
	my $language = $self->language;
	#configuratie-gegevens
	return{
		rooturl => $self->rooturl,
		openURL => $self->openURL,
		request_uri => $self->env->{REQUEST_URI},
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
sub record_view{
        my $self = shift;
        $self->stash->{record_view}||=PeepShow::Handler::Record::View->new();
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

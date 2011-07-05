package PeepShow::help;
use Catmandu::App;

any([qw(get post)],'',sub{
	my $self = shift;
	my $args = $self->page_args_common($self->request->parameters,$self->sess_common,$self->conf_common);
	#openURL
	$args->{services}=$self->services;
	#opensearch
	$args->{languages}=$self->languages;
	$args->{minresults} = Catmandu->conf->{DB}->{index}->{minresults};
	$args->{maxresults} = Catmandu->conf->{DB}->{index}->{maxresults};
	$args->{num_default} = Catmandu->conf->{DB}->{index}->{num_default};
	$self->print_template($self->template('help'),$args);
});
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
                request_uri => $self->env->{REQUEST_URI},
                conf_sorts => Catmandu->conf->{Language}->{$language}->{Record}->{sort_fields},
		openURL => $self->openURL
        } || {};
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
sub languages {
	[grep {$_ ne "default"} keys %{Catmandu->conf->{Language}}];
}
sub services {
	my $self = shift;
	my $services = {};
	foreach(keys %{Catmandu->conf->{Service}}){
		foreach my $svc_id(keys %{Catmandu->conf->{Service}->{$_}}){
			$services->{$svc_id}=1;
		}
	}
	[keys %$services];
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

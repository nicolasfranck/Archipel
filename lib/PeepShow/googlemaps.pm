package PeepShow::googlemaps;
use Catmandu::App;

any([qw(get post)],'',sub{
        my $self = shift;
        my $page_args_common = $self->page_args_common($self->params_common,$self->sess_common,$self->conf_common);
        $self->print_template($self->template('googlemaps'),$page_args_common);
});

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
		rooturl => $self->rooturl,openURL => $self->openURL
	};
}
sub page_args_common{
	my($self,$params_common,$sess_common,$conf_common)=@_;
	return{
		%$params_common,%$sess_common,%$conf_common
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

sub rooturl{
	return Catmandu->conf->{rooturl};
}
sub openURL {
        Catmandu->conf->{openURL};
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

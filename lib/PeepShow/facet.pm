package PeepShow::facet;
use Catmandu::App;

use Plack::Util;
use JSON;
use Try::Tiny;
use Clone qw(clone);

any([qw(get post)],'',sub{
	my $self = shift;

	#parameters
	my $params = $self->request->parameters;
	my $q = $params->{q};
	my $index = $params->{index};

	my($hits,$totalhits,$err,$restfields);
	#opzoeken in index
	if(defined($q) && $q ne ""){
		try{
			($hits,$totalhits,$restfields)=$self->index($index)->search($q,%$params);
		}catch{
			$err = $_;
		};
	}else{
		$err = "no query given";
	}
	if($err){
		$self->send({errors=>["$err"]});	
	}elsif($totalhits==0){
		$self->send({errors=>["results empty"]});
	}else{
		$self->send($restfields->{facet_counts});
	}
});
sub json {
	$_[0]->stash->{json} ||= JSON->new;
}
sub index {
	my($self,$index) = @_;
	$index = defined($index) && defined(Catmandu->conf->{index}->{$index})? $index : Catmandu->conf->{app}->{facet}->{index}->{default};
	$self->stash->{$index} ||= do{
		my $class = Catmandu->conf->{index}->{$index}->{class};
		my $args = Catmandu->conf->{index}->{$index}->{args};
		Plack::Util::load_class($class)->new(%$args);
	};
}
sub send {
	my($self,$response)=@_;
	$self->response->content_type("application/json; charset=utf-8");
	$self->print($self->json->encode(fix($response) || {}));
}
sub fix {
	my $hash = shift;
	return $hash if !(defined($hash) && defined($hash->{facet_fields}));
	my $new = clone($hash);
	foreach(keys %{$hash->{facet_fields}}){
		$new->{facet_fields}->{$_} = {@{$hash->{facet_fields}->{$_}}};
	}
	return $new;
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

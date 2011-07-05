package PeepShow::xml;
use Catmandu::App;
use Plack::Util;
use PeepShow::Resolver::DB;
use Benchmark;

any([qw(get post)],'',sub{
	my $self = shift;
	my $rft_id = $self->request->parameters->{rft_id};
	my $format = $self->request->parameters->{format};
	if(defined($rft_id) && $rft_id ne ""){
		my $record = $self->db->load($rft_id);
		my $xml = $record->{fXML}->[0];
		$format = (defined($format) && defined($self->marc_transformations->{$format}))? $format:undef;
		if(!defined($format)){
			$self->response->content_type('application/xml');
			$self->print($xml);
		}else{
			my $formatted_xml = $self->marc_transformations->{$format}->transform($xml);
			my $content_type = $self->marc_transformations->{$format}->content_type;
			$self->response->content_type($content_type);
			$self->print($formatted_xml);
		}
	}
});

sub db{
	my $self = shift;
	$self->stash->{db}||=PeepShow::Resolver::DB->new();
}

sub marc_transformations {
        my $self = shift;
        $self->stash->{marc_transformations}||=$self->load_transformations;
}
sub load_transformations{
        my $self = shift;
        my $hash = {};
        my $t = Catmandu->conf->{Marc}->{Transformations};
        foreach my $key(keys %$t){
                my $class=$t->{$key};
                Plack::Util::load_class($class);
                $hash->{$key}=$class->new();
        }
        $hash || {};
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

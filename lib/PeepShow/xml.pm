package PeepShow::xml;
use Catmandu::App;

use parent qw(PeepShow::App::Common);

use Plack::Util;

any([qw(get post)],'',sub{
	my $self = shift;
	my $params = $self->request->parameters;
	my $rft_id = $params->{rft_id};
	my $format = $params->{format};

	if(defined($rft_id) && $rft_id ne ""){
		my $record = $self->db->load($rft_id);
		my $xml = (defined($record->{fXML}) && ref $record->{fXML} eq "ARRAY" && scalar(@{$record->{fXML}})>0)? $record->{fXML}->[0]:undef;
		return if !(defined($xml) && $xml ne "");
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

sub marc_transformations {
        my $self = shift;
        $self->stash->{marc_transformations}||=$self->load_transformations;
}
sub load_transformations{
        my $self = shift;
        my $hash = {};
        my $t = Catmandu->conf->{package}->{Marc}->{Transformations};
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

package PeepShow::xml;
use Catmandu::App;

use parent qw(PeepShow::App::Common PeepShow::App::Marc);

use Plack::Util;

any([qw(get post head)],'',sub{
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
			$xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>".$xml;
			$self->send(\$xml);
		}else{
			my $formatted_xml = $self->marc_transformations->{$format}->transform($xml);
			my $content_type = $self->marc_transformations->{$format}->content_type;
			$self->send(\$formatted_xml);
			#hier wordt wél print gebruikt omdat text geflagged is door Perl als utf-8 en niet als dusdanig naar buiten
			#mag vooraleer $self->print die als echte utf-8 heeft geëncodeerd!
			#error: body must be bytes and should not contain wide characters! 
			# -> wegens perl-utf8!
		}
	}
});

sub send {
	my($self,$xml)=@_;
	my $params = $self->request->parameters;
	$self->response->content_type('application/xml; charset=utf-8');
	$self->response->header("Content-Disposition" => "attachment; filename='".$params->{rft_id}.".xml'") if $params->{download};
	$self->print($$xml);
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

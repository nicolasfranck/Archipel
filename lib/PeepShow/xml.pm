package PeepShow::xml;
use Catmandu::App;

use parent qw(PeepShow::App::Common PeepShow::App::Marc);

use Plack::Util;

my $xml_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";

any([qw(get post head)],'',sub{
	my $self = shift;
	my $params = $self->request->parameters;
	my $rft_id = $params->{rft_id};
	my $format = $params->{format};

	if(defined($rft_id) && $rft_id ne ""){
		my $record = $self->db->store->dba->load($rft_id);
		my $xml = (defined($record->{fXML}) && ref $record->{fXML} eq "ARRAY" && scalar(@{$record->{fXML}})>0)? $record->{fXML}->[0]:undef;
		if(defined($xml) && $xml ne ""){
			$format = (defined($format) && defined($self->marc_transformations->{$format}))? $format:undef;
			if(!defined($format)){
				$xml = $xml_header.$xml;
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
		}else{
			my $xml = $self->xml_simple->XMLout($record);
			$xml = $xml_header.$xml;
                        $self->send(\$xml);
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
sub xml_simple {
	$_[0]->stash->{xml_simple} ||= XML::Simple->new;
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

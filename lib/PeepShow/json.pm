package PeepShow::json;
use Catmandu::App;

use parent qw(PeepShow::App::Common);
use Plack::Util;
use JSON;

any([qw(get post)],'',sub{
	my $self = shift;
	my $params = $self->request->parameters;
	my $rft_id = $params->{rft_id};
	my $pretty = $params->{pretty} // 1;
	if(defined($rft_id) && $rft_id ne ""){
		my $record = $self->db->store->dba->load($rft_id) || {}; 
		delete $record->{fXML} if defined($record) && defined($record->{fXML});
		$self->response->content_type('application/json; charset=utf-8');
		my $json = $pretty ? $self->json->pretty->encode($record) : $self->json->encode($record);
		$self->print($json);
	}
});
sub json {
	$_[0]->stash->{json} ||= JSON->new;
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

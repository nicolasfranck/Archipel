package PeepShow::cart;
use Catmandu::App;
use JSON;
use PeepShow::Handler::Cart::Devs;

any([qw(get post)],'',sub{
	my $self = shift;
	my $sess = $self->request->session;
	my $sessid = $self->request->session_options->{id};
	my $params = $self->request->parameters;
	my $response = {};	
	my $handler = PeepShow::Handler::Cart::Devs->new(stash => $sess->{devs} ||{},params => $params);
	my $start = time;
	($response,$sess->{devs}) = $handler->handle();
	my $end = time;
	$response->{req_time}=$end - $start;
	$self->response->content_type("application/json; charset=utf-8");
	$self->print(encode_json($response));
});

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

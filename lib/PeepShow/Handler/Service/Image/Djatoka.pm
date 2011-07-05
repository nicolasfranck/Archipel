package PeepShow::Handler::Service::Image::Djatoka;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;
	my $server = Catmandu->conf->{rooturl}.Catmandu->conf->{Service}->{Image}->{zoomer}->{Server};
	my $code = $record->{access}->{services}->{zoomer}? 200:201;
	return {
		path => $record->{media}->[$opts->{item_id} - 1]->{file}->[0]->{url},
		server => $server,
		rooturl => Catmandu->conf->{rooturl}
	},$code,undef;
}

1;

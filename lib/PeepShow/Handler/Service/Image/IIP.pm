package PeepShow::Handler::Service::Image::IIP;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;	
	my $item = $record->{media}->[$opts->{item_id} - 1];
	my $server = Catmandu->conf->{rooturl}.Catmandu->conf->{Service}->{Image}->{zoomer}->{Server};
	my $code = $record->{access}->{services}->{zoomer}? 200:201;
	return {
		path => $item->{file}->[0]->{path},
		server => $server,
		alt_url => $item->{devs}->{large}->{url},
		rooturl => Catmandu->conf->{rooturl}
	},$code,undef;
}

1;

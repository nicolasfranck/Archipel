package PeepShow::Handler::Service::Image::IIP;
use strict;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;	
	my $item = $record->{media}->[$opts->{item_id} - 1];
	my $server = Catmandu->conf->{all}->{rooturl}.Catmandu->conf->{context}->{Image}->{zoomer}->{Server};
	my $code = $record->{access}->{services}->{zoomer}? 200:201;
	return {
		path => $item->{file}->[0]->{path},
		server => $server,
		alt_url => $item->{devs}->{large}->{url},
		rooturl => Catmandu->conf->{all}->{rooturl}
	},$code,undef;
}

1;

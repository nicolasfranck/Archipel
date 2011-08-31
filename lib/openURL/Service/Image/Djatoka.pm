package openURL::Service::Image::Djatoka;
use strict;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;
	my $server = Catmandu->conf->{all}->{rooturl}.Catmandu->conf->{middleware}->{openURL}->{resolve}->{context}->{Image}->{zoomer}->{Server};
	return {
		path => $record->{media}->[$opts->{item_id} - 1]->{file}->[0]->{url},
		server => $server,
		rooturl => Catmandu->conf->{all}->{rooturl}
	},200,undef;
}

1;

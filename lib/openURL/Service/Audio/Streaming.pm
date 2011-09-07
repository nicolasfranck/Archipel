package openURL::Service::Audio::Streaming;
use strict;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$info,$record)=@_;
	return {
		file => $record->{media}->[$info->{item_id}-1]->{file},
		streamer => Catmandu->conf->{middleware}->{openURL}->{resolve}->{context}->{Audio}->{audiostreaming}->{Streamer},
		rooturl => Catmandu->conf->{all}->{rooturl}
	},200,undef;
}

1;

package openURL::Service::Video::Streaming;
use strict;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$info,$record)=@_;
	return {
		url => $record->{media}->[$info->{item_id}-1]->{file}->[0]->{url},
		streaming_provider => $record->{media}->[$info->{item_id}-1]->{file}->[0]->{streaming_provider},
		thumbnail => $record->{media}->[$info->{item_id}-1]->{devs}->{thumbnail},
		rooturl => Catmandu->conf->{all}->{rooturl}
	},200,undef;
}

1;

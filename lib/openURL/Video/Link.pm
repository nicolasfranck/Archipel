package PeepShow::Handler::Service::Video::Link;
use strict;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$info,$record)=@_;
	return {
		url => $record->{media}->[$info->{item_id}-1]->{file}->[0]->{url},
		thumbnail => $record->{media}->[$info->{item_id}-1]->{devs}->{thumbnail}
	},200,undef;
}

1;

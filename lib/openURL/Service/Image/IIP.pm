package openURL::Service::Image::IIP;
use strict;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;	
	my $item = $record->{media}->[$opts->{item_id} - 1];
	my $server = Catmandu->conf->{all}->{rooturl}.Catmandu->conf->{middleware}->{openURL}->{resolve}->{context}->{Image}->{zoomer}->{Server};
	return {
		path => $item->{file}->[0]->{path},
		server => $server,
		rooturl => Catmandu->conf->{all}->{rooturl}
	},200,undef;
}

1;

package openURL::Service::Image::IIP;
use strict;
use Catmandu;

my $server = Catmandu->conf->{middleware}->{openURL}->{resolve}->{context}->{Image}->{zoomer}->{Server};
my $rooturl = Catmandu->conf->{all}->{rooturl};

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;	
	my $item = $record->{media}->[$opts->{item_id} - 1];
	return {
		path => $item->{file}->[0]->{path},
		server => $server,
		rooturl => $rooturl
	},200,undef;
}

1;

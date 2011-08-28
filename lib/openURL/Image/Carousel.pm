package PeepShow::Handler::Service::Image::Carousel;
use strict;
use Catmandu;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;
	my $rels = [];
	foreach my $item(@{$record->{media}}){
		push @$rels,{
			thumbnail => $item->{devs}->{thumbnail},
			title => $item->{title},
			item_id => $item->{item_id},
			context => $item->{context}
		};
	}
	return {
		rft_id => $record->{_id},
		rels => $rels,
		rooturl => Catmandu->conf->{all}->{rooturl},
		item_id => $opts->{item_id},
		mapping => Catmandu->conf->{service_aggregate}->{carousel}->{mapping},
		openURL => Catmandu->conf->{app}->{openURL}
	},200,undef;
}

1;

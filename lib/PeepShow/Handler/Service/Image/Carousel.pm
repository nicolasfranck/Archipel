package PeepShow::Handler::Service::Image::Carousel;
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
			item_id => $item->{item_id}
		};
	}
	return {
		rft_id => $record->{_id},
		rels => $rels,
		rooturl => Catmandu->conf->{rooturl},
		item_id => $opts->{item_id}
	},200,undef;
}

1;

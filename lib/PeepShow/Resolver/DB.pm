package PeepShow::Resolver::DB;
use Catmandu;
use Try::Tiny;
use Plack::Util;

sub new {
	my $class = shift;
	my $c;
	my $a;
	#index
	$c = Catmandu->conf->{index}->{core}->{class};
        $a = Catmandu->conf->{index}->{core}->{args};
        Plack::Util::load_class($c);
        my $index = $c->new(%$a);
	#store
	$c = Catmandu->conf->{database}->{core}->{class};
        $a = Catmandu->conf->{database}->{core}->{args};
        Plack::Util::load_class($c);
	my $store = $c->new(%$a);
	bless {
		store => $store,index=>$index
	},$class;
}
sub store {
	shift->{store};
}
sub index {
	shift->{index};
}
sub load{
	my($self,$rft_id)=@_;
	return $self->store->load($rft_id);
}

sub query_store{
	my($self,$query,%args)=@_;	
	$args{reify} = $self->store;
	my $hits;my $totalhits;my $err;my $rest_fields;
	try{
		($hits,$totalhits,$rest_fields)=$self->index->search($query,%args);
	}catch{		
		$err = "Error";
	};
	return undef,undef,$err,undef if defined($err);
	return $hits,$totalhits,undef,$rest_fields;
}
sub query_index{
	my($self,$query,%args)=@_;
	delete $args{reify} if defined($args{reify});
	my $hits;my $totalhits;my $err;my $rest_fields;
	try{
		($hits,$totalhits,$rest_fields)=$self->index->search($query,%args);
	}catch{
		$err = "Error";
	};
	return undef,undef,$err,undef if defined($err);
	return $hits,$totalhits,undef,$rest_fields;
}

1;

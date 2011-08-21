package Cart::Singleton;
use strict;
use warnings;
use Hash::Merge::Simple qw(merge);
use Clone qw(clone);
#bij Hash::Merge
#i.e. rijen zullen elkaar gewoon overschrijven, ipv aanvullen
#Hash::Merge::specify_behavior({
#    SCALAR => {
#            SCALAR => sub { $_[1] },
#            ARRAY  => sub { [ $_[0], @{$_[1]} ] },
#            HASH   => sub { $_[1] } },
#    ARRAY => {
#            SCALAR => sub { $_[1] },
#            ARRAY  => sub { $_[1] },
#            HASH   => sub { $_[1] } },
#    HASH => {
#            SCALAR => sub { $_[1] },
#            ARRAY  => sub { [ values %{$_[0]}, @{$_[1]} ] },
#            HASH   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) } }
#
#});


sub new {
	my($class,%opts) = @_;
	bless {stash=>$opts{stash} || {}},$class;
}
sub stash {
	my $self = shift;
	if(@_){$self->{stash}=shift;}
	$self->{stash};
}
sub insert{
	my($self,$id,$obj)=@_;	
	#automatische merge als het al bestaat
	if(defined($self->stash->{$id})){		
		my $old = $self->stash->{$id};				
		$self->stash->{$id}=merge($old,$obj);		
	}else{		
		$self->stash->{$id}=$obj;
	}	
	return 1;	
}

sub remove{
	my($self,$id)=@_;	
	if(defined($self->stash->{$id})){
		delete($self->stash->{$id});
		return 1;
	}
	return 0;
}
sub exists{
	my($self,$id)=@_;
	return defined($self->stash->{$id});
}
sub get{
	my($self,$id)=@_;
	return clone($self->stash->{$id});
}
sub num{
	my $self = shift;
	return scalar(keys %{$self->stash});
}

sub array{
	my($self,$sort) = @_;
	my @keys;
	if($sort){
		@keys = sort keys %{$self->stash};
	}else{
		@keys=keys %{$self->stash};
	}
	return map {$self->stash->{$_}} @keys;		
}
sub clear{
	shift->stash({});
}
sub each{
	my($self,$func)=@_;
	foreach(keys %{$self->stash}){
		&$func($self->stash->{$_});
	}
}

1;

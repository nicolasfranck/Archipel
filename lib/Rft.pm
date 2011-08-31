package Rft;
#base class for rft_id's

sub new {
	bless {
		_record_id => undef,
		_item_id => 0,
		_error => undef,
		_query => undef,
		_is_id => 1,
	},shift;
}
sub record_id {
	my $self = shift;
	if(@_){$self->{_record_id} = shift;}
	return $self->{_record_id};
}
sub item_id {
	my $self = shift;
        if(@_){$self->{_item_id} = shift;}
        return $self->{_item_id};
}
sub error {
	my $self = shift;
        if(@_){$self->{_error} = shift;}
        return $self->{_error};
}
sub query {
	my $self = shift;
        if(@_){$self->{_query} = shift;}
        return $self->{_query};
}
sub is_id {
	my $self = shift;
	if(@_){$self->{_is_id} = shift;}
	$self->{_is_id};
}

1;

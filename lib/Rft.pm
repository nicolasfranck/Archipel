package Rft;
#base class for rft_id's

sub new {
	bless {
		_record_id => undef,
		_item_id => 0,
		_error => undef,
		_query => undef,
		_is_id => 1,
		_hint => undef
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
#meestal hetzelfde als record_id. 
#van belang wanneer query niets van doen heeft met het record_id. Vb. BHSL_????_0001_AC => hint is "BHSL", en dat kan je dan in je cache linken aan het record dat je achteraf vindt
sub hint {
	my $self = shift;
	if(@_){$self->{_hint} = shift;}
        return $self->{_hint};
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

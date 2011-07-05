package Record::View;
use strict;
use utf8;

sub new {
	my($class,%opts)=@_;
	bless {
		record => $opts{record} || {},
		args => $opts{args} || {},
		sess => $opts{sess} || {},
		params => $opts{params} || {},
		conf => $opts{conf} || {},
		_err => undef,
		_errmsg => undef
	},$class;
}
sub record {
	my $self = shift;
	if(@_){$self->{record}=shift;}
	$self->{record};
}
sub params {
        my $self = shift;
        if(@_){$self->{params}=shift;}
        $self->{params};
}
sub args {
	my $self = shift;
	if(@_){$self->{args}=shift;}
	$self->{args};
}
sub sess {
        my $self = shift;
        if(@_){$self->{sess}=shift;}
        $self->{sess};
}
sub conf {
        my $self = shift;
        if(@_){$self->{conf}=shift;}
        $self->{conf};
}
sub err {
        my $self = shift;
        if(@_){$self->{_err}=shift;}
        $self->{_err};
}
sub errmsg {
        my $self = shift;
        if(@_){$self->{_errmsg}=shift;}
        $self->{_errmsg};
}

1;

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
		env => $opts{env} || {},
		err => undef,
		errmsg => undef
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
sub env {
	$_[0]->{env};
}
sub err {
        my $self = shift;
        if(@_){$self->{err}=shift;}
        $self->{err};
}
sub errmsg {
        my $self = shift;
        if(@_){$self->{errmsg}=shift;}
        $self->{errmsg};
}

1;

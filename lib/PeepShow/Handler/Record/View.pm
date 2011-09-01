package PeepShow::Handler::Record::View;
use strict;
use utf8;
use Catmandu;
use Plack::Util;

sub new {
	bless {
		_conf => Catmandu->conf->{package}->{Record}->{View},
		_stash => {}
	},shift;
}
sub _conf {
	$_[0]->{_conf}
}
sub _stash {
	my $self = shift;
	if(@_){$self->{_stash}=shift;}
	$self->{_stash};
}
sub handle{
        my($self,$page_args) = @_;
	my $view = (defined($page_args->{params}->{view}) && defined($self->_conf->{$page_args->{params}->{view}}))? $page_args->{params}->{view}:$self->_conf->{default};
	my $package = "Record::View::".$self->_conf->{$view};
	$self->check_package($package) or croak("cannot find $package");
	my $v =	$package->new(%$page_args);
	$v->prepare;
	my $hash = {
		template_key => lc($view) ,
		err => $v->err,
		errmsg => $v->errmsg
	};
	return $hash;
}
sub check_package {
	my($self,$package)=@_;
	$self->_stash->{$package} ||= $self->load_package($package);
}
sub load_package {
	my($self,$package)=@_;
	Plack::Util::load_class($package);
	return 1;
}

1;


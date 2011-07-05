package PeepShow::Handler::Record::View;
use Catmandu;
use Plack::Util;

sub new {
	bless {
		_conf => Catmandu->conf->{Record}->{View},
		_stash => {}
	},shift;
}
sub _conf {
	shift->{_conf}
}
sub _stash {
	my $self = shift;
	if(@_){$self->{_stash}=shift;}
	$self->{_stash};
}
sub handle{
        my($self,$opts) = @_;
	my $view = (defined($opts->{view}) && defined($self->_conf->{$opts->{view}}))? $opts->{view}:$self->_conf->{default};
	my $package = "Record::View::".$self->_conf->{$view};
	$self->check_package($package) or croak("cannot find $package");
	my $v =	$package->new(
		record => $opts->{record},
		args => $opts->{args},
		params => $opts->{params},
		conf => $opts->{conf},
		sess => $opts->{sess}
	);
	$v->prepare;
	my $hash = {
		record => $v->record,
		args => $v->args,
		params => $v->params,
		conf => $v->conf,
		sess => $v->params,		
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


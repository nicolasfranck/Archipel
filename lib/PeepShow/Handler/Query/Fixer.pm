package PeepShow::Handler::Query::Fixer;
use strict;
use utf8;
use Catmandu;
use Plack::Util;

sub new {
	bless {
		_conf => Catmandu->conf->{package}->{Query}->{Fixer},
		_stash => {}
	},shift;
}
sub _conf {
	shift->{_conf};
}
sub _stash {
	my $self = shift;
	if(@_){$self->{_stash}=shift;}
	$self->{_stash};
}
sub handle{
	my($self,$params) = @_;
	my $search_type = $params->{search_type};
	my $package = defined($search_type) && defined($self->_conf->{$search_type})? $self->_conf->{$search_type}:$self->_conf->{default};
	$self->get_package($package)->fix($params);
}
sub get_package {
	my($self,$package)=@_;
	$self->load_package($package) if(not defined($self->_stash->{$package}));
	$self->_stash->{$package} ||= $package->new();
}
sub load_package {
	my($self,$package)=@_;
	Plack::Util::load_class($package);
}

1;

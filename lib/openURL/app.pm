package openURL::app;
use strict;
use PeepShow::Resolver::DB;
use List::MoreUtils qw(first_index);
use Catmandu;
use Plack::Util;

sub new {
	my $class = shift;
	my @rft_parsers = ();
	return bless {
		db => PeepShow::Resolver::DB->new,
		stash => {},
	},$class;
}
sub stash {
	my $self = shift;
	if(@_){$self->{stash}=shift;}
	$self->{stash};
}
sub db {
	my $self = shift;
	if(@_){$self->{db}=shift;}
	$self->{db};
}
sub handle{
	my($self,$opts,$env)=@_;

	my @keys = qw(id type);
	foreach(@keys){
		if(!(defined($opts->{$_}) && $opts->{$_} ne "")){
			return undef,undef,500,"$_ is not defined";
		}
	}
	my $id = $opts->{id};
	my $type = $opts->{type};
	
	#bestaat record?
	my $record = $self->db->load($id);
	if(!(defined($record) && defined($record->{media}))){
		return undef,undef,500,"$id does not exist";
	}
	#zoek pakket
	my($package,$args,$template) = $self->get_handling_package($type);
	if(not defined($package)){
		#handling_package_undefined
		return undef,undef,500,"Technical error. Handling package for $id-$type not defined in configuration file";
	}
	#load class	
	my($hash,$code,$err)=$self->get_package($package,$args)->handle({
		id => $id,type => $type, env => $env
	},$record);
	return $hash,$template,$code,$err;
}
sub get_package {
	my($self,$package,$args)=@_;
	$self->stash->{$package} ||= $self->build_package($package,$args);
}
sub build_package {
	my($self,$package,$args)=@_;
	Plack::Util::load_class($package);
	$package->new(%$args);
}
sub get_handling_package {
	my($self,$type)=@_;
	my $package;
	my $template;
	my $args;
	my $types = Catmandu->conf->{middleware}->{openURL}->{app}->{types};
	if(defined($types->{$type}) && defined($types->{$type})){
		$package = $types->{$type}->{HandlingPackage};
		$args = $types->{$type}->{args} || {};
		$template = $types->{$type}->{Template};
	}
	return $package,$args,$template;
}
1;

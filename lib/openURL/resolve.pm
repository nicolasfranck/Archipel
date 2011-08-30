package openURL::resolve;
use strict;
use PeepShow::Resolver::DB;
use List::MoreUtils qw(first_index);
use Catmandu;
use Plack::Util;
use Cache::FastMmap;
use Data::Dumper;

sub new {
	my $class = shift;
	my @rft_parsers = ();
	my $openURL = Catmandu->conf->{middleware}->{openURL}->{resolve};
	foreach my $rft(@{$openURL->{rft_id}->{formats}}){
		my $class = $rft->{class};
		my $args = $rft->{args};
		Plack::Util::load_class($class);
		push @rft_parsers,$class->new(%$args);
	}
	my @acls = ();
	foreach my $acl(@{$openURL->{acls}}){
		my $class = $acl->{class};
		my $args = $acl->{args};
		Plack::Util::load_class($class);
                push @acls,$class->new(%$args);
	}
	my $cache = Cache::FastMmap->new(
		cache_size => '50m'
	);	
	return bless {
		db => PeepShow::Resolver::DB->new,
		stash => {},
		aliases => $openURL->{aliases},
		rft_id_parsers => \@rft_parsers,
		acls => \@acls,
		cache => $cache
	},$class;
}
sub alias {
	my($self,$name)=@_;
	defined($self->{aliases}->{$name}) ? $self->{aliases}->{$name} : $name;
}
sub rft_id_parsers {
	$_[0]->{rft_id_parsers};
}
sub acls {
	$_[0]->{acls};
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
sub cache {
	$_[0]->{cache};
}
sub get_record {
	my($self,$key,$is_id)=@_;
	#key -> query of gewoon record_id
	my $record = $self->cache->get($key);
	if(!defined($record)){
		if($is_id){
			print STDERR "key $key retrieving from database\n";
			$record = $self->db->store->dbb->load($key);
		}else{
			print STDERR "key $key retrieving from index\n";
			my($hits,$totalhits,$err) = $self->db->query_store($key,dbb=>1);
			$record = $hits->[0] if !defined($err) && $totalhits > 0;
		}
		if(defined($record)){
			print "record is defined now\n";
			print Dumper($self->cache);
			my $is_saved = $self->cache->set($key,$record);
			print $is_saved?"was saved\n":"was not saved\n";
		}
		print Dumper($self->cache->get($key));
	}else{
		print STDERR "key $key found in cache\n";
	}
	return $record;
}
sub handle{
	my($self,$opts,$env)=@_;

	my $rft_id = $opts->{rft_id};
	my $item_id;
	my $svc_id = $opts->{svc_id};
	$svc_id = $self->alias($svc_id);
	my $query;

	#syntactische controle van rft_id
		#parse rft_id
		my $success = 0;
		my $record_id;
		my $is_id = 0;
		
		foreach my $rft_id_parser(@{$self->rft_id_parsers}){
			$success = $rft_id_parser->parse($opts->{rft_id});
			if($success){
				$query = $rft_id_parser->query;
				$item_id = $rft_id_parser->item_id;			
				$is_id = $rft_id_parser->is_id;
				$record_id = $rft_id_parser->record_id;
				last;
			}
		}
		if(!$success){
			return undef,undef,500,"rft_id ".$opts->{rft_id}." invalid";
		}
	my $record = $self->get_record($is_id ? $record_id : $query,$is_id);
	#bestaat record?
#	if($is_id){
#		$record = $self->db->store->dbb->load($record_id);
#	}else{
#		my($hits,$totalhits,$err) = $self->db->query_store($query,dbb=>1);	
#		$record = $hits->[0] if !defined($err) && $totalhits > 0;
#	}
	if(not defined($record)){
		return undef,undef,500,"$query does not exist";
	}
	$rft_id = $record->{_id};#want bij file-item moet je dit nog neerschrijven..
	#zoek item in record
	my $index_item = $item_id - 1;
	my $item = $record->{media}->[$index_item] if defined($record->{media}->[$index_item]);	
	if(not defined($item)){
		#item_id_not_found
		return undef,undef,500,"$rft_id-$item_id does not exist";
	}	
	#bestaat svc_id voor deze item_id?
	my $services = $item->{services};
	my $index_svc_id=first_index {$_ eq $svc_id} @$services;
	if($index_svc_id < 0){
		#svc_id_not_found
		return undef,undef,500,"$rft_id-$item_id-$svc_id does not exist";
	}
	#toegang tot svc_id?
	my $allowed = 1;
	foreach my $acl(@{$self->acls}){
		if(!$acl->is_allowed($env,$record,$item_id,$svc_id)){
			$allowed = 0;
			last;
		}
	}
	return undef,undef,401,"" if !$allowed;
	#context?
	my $context = $item->{context};#Image, Video
	if(not defined($context)){
		#context_not_in_database
		return undef,undef,500,"Technical error. Context of $rft_id-$item_id undefined in database";
	}
	#zoek pakket
	my($package,$args,$template) = $self->get_handling_package($context,$svc_id);
	if(not defined($package)){
		#handling_package_undefined
		return undef,undef,500,"Technical error. Handling package for $rft_id-$item_id-$svc_id not defined in configuration file";
	}
	#path
	my $path = $item->{file};
	if(not defined($path)){
		#path_undefined
		return undef,undef,500,"Technical error. Location of $rft_id-$item_id-$svc_id not in database";
	}
	#load class	
	my($hash,$code,$err)=$self->get_package($package,$args)->handle({
		rft_id => $rft_id,item_id=>$item_id,svc_id=>$svc_id
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
	my($self,$context,$svc_id)=@_;
	my $package;
	my $template;
	my $args;
	my $contexts = Catmandu->conf->{middleware}->{openURL}->{resolve}->{context};
	if(defined($contexts->{$context}) && defined($contexts->{$context}->{$svc_id})){
		$package = $contexts->{$context}->{$svc_id}->{HandlingPackage};
		$args = $contexts->{$context}->{$svc_id}->{args} || {};
		$template = $contexts->{$context}->{$svc_id}->{Template};
	}
	return $package,$args,$template;
}
1;

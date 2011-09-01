package openURL::resolve;
use strict;
use PeepShow::Resolver::DB;
use List::MoreUtils qw(first_index);
use Catmandu;
use Plack::Util;
use Cache::FastMmap;

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
		%{Catmandu->conf->{middleware}->{openURL}->{resolve}->{cache}->{args}}
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
	$_[0]->{db};
}
sub cache {
	$_[0]->{cache};
}
sub get_record {
	my($self,$key,$hint,$is_id)=@_;
	#key -> query of gewoon record_id
	my $record = $self->cache->get($key);
	if(!defined($record)){
		if($is_id){
			#print STDERR "key $key retrieving from database\n";
			$record = $self->db->store->dbb->load($key);
		}else{
			my $search_index = 1;
			#laatste poging: zit er geen mapping in de cache? vb. BHSL => rug01:000000001
			if(defined($hint)){
				#print STDERR "looking for mapped value for hint $hint\n";
				my $mapping = $self->cache->get($hint);
				if(defined($mapping)){
					#print "found mapped value $$mapping\n";
					$record = $self->cache->get($$mapping);
					if(defined($record)){
						$search_index = 0;
						#print "changing key $key => ";
						$key = $$mapping;
						#print "$key\n";
					}
				}else{
					#print "no mapping found\n";
				}
			}
			if($search_index){
				#opgelet bij dummy-records: als je bags kopiëert en record_id wijzigt,
				#wijzig dan ook de bestandsnamen mee, want slechts 1ste hit wordt
				#gebruikt..
				#print STDERR "key $key retrieving from index\n";
				my($hits,$totalhits,$err) = $self->db->query_store($key,dbb=>1,limit=>1);
				if(!defined($err) && $totalhits > 0){
					$record = $hits->[0];
					#plaats de mapping BHSL -> rug01:000000001
					my $is_saved = $self->cache->set($hint,\$record->{_id});
					#print "mapping $hint => $record->{_id} ";
					#print $is_saved ? "was saved\n":"was not saved\n";
					$key = $record->{_id};
					#print "mapping placed from $hint => ".${$self->cache->get($hint)}."\n";
				}
			}
		}
		if(defined($record)){
			#print STDERR "record is defined now\n";
			my $is_saved = $self->cache->set($key,$record);
			
			#print "setting key $key in cache\n" if $is_saved;
			#print $is_saved?"was saved\n":"was not saved\n";
		}
	}else{
		#print STDERR "key $key found in cache\n";
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
	my $hint;
	
	foreach my $rft_id_parser(@{$self->rft_id_parsers}){
		$success = $rft_id_parser->parse($opts->{rft_id});
		if($success){
			$query = $rft_id_parser->query;
			$item_id = $rft_id_parser->item_id;			
			$is_id = $rft_id_parser->is_id;
			$record_id = $rft_id_parser->record_id;
			$hint = $rft_id_parser->hint;
			last;
		}
	}
	if(!$success){
		return undef,undef,500,"rft_id ".$opts->{rft_id}." invalid";
	}
	#haal record op (1.cache 2. database 3. index en dan databank)
	my $record = $self->get_record($is_id ? $record_id : $query,$hint,$is_id);
	if(not defined($record)){
		return undef,undef,404,"$query does not exist";
	}
	$record_id = $record->{_id};#want bij Rft::Fedora moet je dit nog neerschrijven..
	#zoek item in record
	my $index_item = $item_id - 1;
	my $item;
	$item = $record->{media}->[$index_item] if defined($record->{media}->[$index_item]);	
	if(not defined($item)){
		#item_id_not_found
		return undef,undef,404,"$record_id-$item_id does not exist";
	}	
	#bestaat svc_id voor deze item_id?
	my $services = $item->{services};
	my $index_svc_id=first_index {$_ eq $svc_id} @$services;
	if($index_svc_id < 0){
		#svc_id_not_found
		return undef,undef,404,"$record_id-$item_id-$svc_id does not exist";
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
		return undef,undef,500,"Technical error. Context of $record_id-$item_id undefined in database";
	}
	#zoek pakket
	my($package,$args,$template) = $self->get_handling_package($context,$svc_id);
	if(not defined($package)){
		#handling_package_undefined
		return undef,undef,500,"Technical error. Handling package for $record_id-$item_id-$svc_id not defined in configuration file";
	}
	#path
	my $path = $item->{file};
	if(not defined($path)){
		#path_undefined
		return undef,undef,500,"Technical error. Location of $record_id-$item_id-$svc_id not in database";
	}
	#load class	
	my($hash,$code,$err)=$self->get_package($package,$args)->handle({
		item_id=>$item_id,svc_id=>$svc_id
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

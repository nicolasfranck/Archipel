package PeepShow::Handler::Service::Simple;
use PeepShow::Resolver::DB;
use List::MoreUtils qw(first_index);
use Catmandu;
use Plack::Util;
use Text::Glob qw(glob_to_regex);

sub new {
	my $class = shift;
	return bless {
		db => PeepShow::Resolver::DB->new,
		stash => {},
		allowed_range => glob_to_regex(Catmandu->conf->{allowed_range}),
		file_item => qr/^([\w_\-]+_AC)$/,
		rug01_item => qr/^(rug01:\d{9}):(\d+)$/,
		aliases => {
			"zoomer_fullscreen" => "zoomer"
		}
	},$class;
}
sub alias {
	my($self,$name)=@_;
	defined($self->{aliases}->{$name}) ? $self->{aliases}->{$name} : $name;
}
sub file_item {
	shift->{file_item};
}
sub rug01_item {
	shift->{rug01_item};
}
sub allowed_range {
	shift->{allowed_range};
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

	my $rft_id = $opts->{rft_id};
	my $item_id;
	my $svc_id = $opts->{svc_id};
	$svc_id = $self->alias($svc_id);
	my $query;

	my $sourceIP = $env->{HTTP_X_FORWARDED_FOR} ? $env->{HTTP_X_FORWARDED_FOR} : $env->{REMOTE_HOST};
	my @ips = split(',',$sourceIP);
	$sourceIP = pop(@ips);
	
	#syntactische controle van rft_id
		if(not defined($opts->{rft_id})){
			#rft_id_not_given
			return undef,undef,500,"rft_id ".$opts->{rft_id}." is undefined";
		}
		#rug01-item
		if($opts->{rft_id} =~ $self->rug01_item){
			$rft_id = $1;
			$item_id = $2;
			$query = "id:\"$rft_id\"";
		}
		#file-item
		elsif($opts->{rft_id} =~ $self->file_item){
			my $catch = $1;
                        $catch =~ s/\d{4}_((\d{4})_AC)/????_\1/;
                        $query = "files:$catch";
                        $item_id = int($2);
		}else{
			return undef,undef,500,"rft_id ".$opts->{rft_id}." invalid";
		}
	
	#bestaat record?
	my($hits,$totalhits,$err) = $self->db->query_store($query);
	my $record = $hits->[0] if !defined($err) && $totalhits > 0;
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
	if(defined($record->{access}) && !$record->{access}->{services}->{$svc_id} && $sourceIP !~ $self->allowed_range){
		return undef,undef,401,"";
	}
	#context?
	my $context = $item->{context};#Image, Video
	if(not defined($context)){
		#context_not_in_database
		return undef,undef,500,"Technical error. Context of $rft_id-$item_id undefined in database";
	}
	#en in het conf bestand?
	if(not defined($self->conf->{$context}->{$svc_id})){
		#context_not_in_configuration
		return undef,undef,500,"Technical error. Service $svc_id defined in database, but not in configuration file";
	}
	#zoek pakket
	my $package = $self->conf->{$context}->{$svc_id}->{HandlingPackage};
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
	my($hash,$code,$err)=$self->get_package($package)->handle({
		rft_id => $rft_id,item_id=>$item_id,svc_id=>$svc_id
	},$record);

	#aangezien het record al eens is opgehaald, kunnen we maar best van de gelegenheid gebruik maken
	#om de Show te helpen met het vinden van de template
	my $template = $self->conf->{$context}->{$svc_id}->{Template};
	return $hash,$template,$code,$err;
}
sub get_package {
	my($self,$package)=@_;
	$self->stash->{$package} ||= $self->build_package($package);
}
sub build_package {
	my($self,$package)=@_;
	Plack::Util::load_class($package);
	$package->new();
}
sub conf {
	Catmandu->conf->{Service};
}

1;

package PeepShow::Handler::Cart::Devs;
use Catmandu;
use Cart::Singleton;
use JSON;
use URI::Escape;
use Try::Tiny;
use PeepShow::Resolver::DB;
use List::MoreUtils qw(first_index indexes);

sub new {
	my($class,%opts)=@_;
	my $stash = $opts{stash};
	my $params = $opts{params};
	bless{
		params => $params,
		_cart => Cart::Singleton->new(stash=>$stash),
		_db => PeepShow::Resolver::DB->new,
		
	},$class;
}
sub params {
        my $self = shift;
        if(@_){$self->{params}=shift;}
        $self->{params};
}
sub _cart {
        my $self = shift;
        if(@_){$self->{_cart}=shift;}
        $self->{_cart};
}
sub _db {
        my $self = shift;
        if(@_){$self->{_db}=shift;}
        $self->{_db};
}
sub handle{
	my $self = shift;	

	#configuratie
	my $id_field = Catmandu->conf->{index}->{core}->{args}->{id_field};
	
	#request-parameters
	my $action = $self->params->{action} // "";		
	my $obj_str=$self->params->{obj};
	my $getstash=$self->params->{getstash};	
	my $getelement=$self->params->{getelement};
	my $getnum = $self->params->{getnum};
	my $response = {};
	if(defined($action) && $action ne ""){
		#antwoord
		$response->{action} = $action;
		if($action eq "purge"){
			$response=$self->_purge();
		}
		elsif($action eq "clear"){
			$response=$self->_clear();
		}
		#via params: rft_id,svc_id en cite (1 record mogelijk)
		elsif(defined($self->params->{rft_id})){
			my $rft_id = $self->params->{rft_id};	
			my $record = $self->_db->load($rft_id);
			if(defined($record->{_id})){

				my $obj={rft_id => $rft_id};
				my $res = $self->handleRecord($action,$record,[$obj]);	
				if($res->{err}){
					$response->{err}=$res->{err};
					$response->{errmsg}=$res->{errmsg};
				}else{
					$response->{success}=1;
				}

			}else{
				$response->{err}=1;
				$response->{errmsg}="rft_id_nonexistant";
			}
			
		}
		#via parameter 'obj'=[{rft_id,svc_id,cite},{rft_id,svc_id,cite}] (meerdere records mogelijk)
		elsif(defined($obj_str)){
			my $error=undef;
			my $res={};
			my $obj_array;
			try{
				$obj_array = decode_json(uri_unescape($obj_str));	
			}catch{
				$error=1;
			};
			if(not defined($error)){
				my %unique = ();
				$unique{$_->{rft_id}}=1 foreach @$obj_array;
				my $query = join(' OR ',map {
					"($id_field:\"$_\")";
				} keys %unique);
				
				my($hits,$totalhits,$err) = $self->_db->query_store($query);
				if($totalhits>0){
					foreach my $hit(@$hits){
						my @indexes = indexes {$_->{rft_id} eq $hit->{_id}} @$obj_array;
						$response = $self->handleRecord($action,$hit,[@$obj_array[@indexes]]);
						if($response->{err}){
							last;
						}
					}
				}
			}
		}else{
			$response={err=>1,errmsg=>"format_invalid"};
		}
	}
	
	#bijkomende functionaliteit, vooral om informatie te verkrijgen
	if($getstash){
		$response->{stash}=$self->_cart->stash || {};
	}
	if(defined($self->params->{rft_id})){
		if($getelement){
			$response->{element}=$self->_cart->get($self->params->{rft_id})||{};
		}	
	}
	if(defined($getnum) && $getnum eq "1"){
		$response->{num} =  $self->_cart->num;
	}
	return $response,$self->_cart->stash;
}

sub handleRecord{
	my($self,$action,$hit,$objects)=@_;
	#conf	
	my $default_service = Catmandu->conf->{app}->{cart}->{default_service};
	my $max = Catmandu->conf->{app}->{cart}->{max};
	my $response = {action=>$action};
	my $rft_id = $hit->{_id};
	my $msg="";
	my $errmsg="";
	my $err=0;
	#acties
	if(defined($action)){
		
		if($action eq "insert"){
			if($self->_cart->num >= $max){
				$response = {action=>$action,err=>1,errmsg=>"INSERT_LIMIT_REACHED"};
				return $response;
			}
			#itereren over objecten die verband houden met huidige hit
			foreach my $obj(@$objects){
				$msg="";
				$errmsg="";
				$err=0;
				my $newobj;
				#volledig record toevoegen					
				if(not($self->_cart->exists($rft_id))){
					$newobj->{marked}=0;
					$newobj->{title}=$hit->{title};
					$newobj->{poster_item_id} = $hit->{poster_item_id};
					$newobj->{posterwidth}=$hit->{media}->[$hit->{poster_item_id} - 1]->{devs}->{thumbnail}->{width};
					$newobj->{posterheight}=$hit->{media}->[$hit->{poster_item_id} - 1]->{devs}->{thumbnail}->{height};
					$newobj->{added}=time;
					$newobj->{numitems}=scalar(@{$hit->{media}});
				}else{
					$newobj = $self->_cart->get($rft_id) || {};
				}	
				$self->_cart->insert($rft_id,$newobj);
			}
			if($err==0){
                                $response={
                                	action => $action,
                                        success => 1,
                                        rft_id => $rft_id,
                                        msg => $msg
                                };
			}else{
                        	$response={action=>$action,err=>1,rft_id=>$rft_id,errmsg=>$errmsg};	                                       
			}
		}elsif($action eq "mark"){

			foreach my $obj(@$objects){					
				$msg="";
				$errmsg="";
				$err=0;

				#verwerking
				if($self->_cart->exists($rft_id)){	
					$self->_cart->stash->{$rft_id}->{marked}=1;
				}else{
					$err = 1;$errmsg="rft_id_nonexistant";
					last;			
				}
			}
			if($err==0){
                        	$response={action => $action,success =>1,rft_id=>$rft_id,msg=>$msg};
                        }else{
                        	$response={action=>$action,err=>1,rft_id=>$rft_id,errmsg=>$errmsg};
                       	}
		}elsif($action eq "unmark"){
                        foreach my $obj(@$objects){
				$msg="";
				$errmsg="";
				$err=0;
                                #verwerking
                      	  	if($self->_cart->exists($rft_id)){
        	                	$self->_cart->stash->{$rft_id}->{marked}=0;
                        	}else{
					$err = 1;$errmsg="rft_id_nonexistant";
                	                last;
                        	}
                        }
                        if($err==0){
                                $response={action => $action,success =>1,rft_id=>$rft_id,msg=>$msg};
                        }else{
                                $response={action=>$action,err=>1,rft_id=>$rft_id,errmsg=>$errmsg};
                        }			
		}elsif($action eq "remove"){
			foreach my $obj(@$objects){
				$msg="";
				$errmsg="";
				$err=0;
				#verwerking
				if($self->_cart->exists($rft_id)){	
					$self->_cart->remove($rft_id);
				}else{
					$err=1;$errmsg="rft_id_nonexistant";
					last;
				}				
			}
			if($err==0){
				$response={action => $action,success =>1,rft_id=>$rft_id};
			}else{
                                $response={action=>$action,err=>1,rft_id=>$rft_id,errmsg=>$errmsg};
                        }
		}else{
			$response={
				err=>1,
				action => $action,
				errmsg => "action_not_upported"
			};
		}
	}
	else{
		$response->{err}=1;
		$response->{errmsg}="action_not_given";
	}		
	return $response;
}

sub _purge{
	my $self = shift;
	my $count=0;
	my $msg;	
	my $response={action=>"purge"};
	foreach my $rft_id(keys %{$self->_cart->stash}){
		if($self->_cart->stash->{$rft_id}->{marked} == 1){
			$self->_cart->remove($rft_id);
		}						
	}
	$response={action=>"purge",success=>1};	
	return $response;
}
sub _clear{
	my $self = shift;
	$self->_cart->clear();
	return {
		success=>1,
		msg => "cart_empty"
	};
}

1;

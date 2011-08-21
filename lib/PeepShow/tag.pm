package PeepShow::tag;
use Catmandu::App;
use parent qw(PeepShow::App::Common);
use Plack::Util;
use JSON;
use Captcha::reCAPTCHA;
use Try::Tiny;
use Clone qw(clone);
use utf8;

any([qw(get post)],'',sub{
	my $self = shift;
	
	my $params = $self->request->parameters;
	my $action = $params->{action};
	my $tag = $params->{tag};
	my $rft_id = $params->{rft_id};
	my $item_id = $params->{item_id};
	
	my $response = {action=>$action,errors=>[],success=>0};
	#action?
	if(defined($action) && $action eq "add"){
		#parameters degelijk ingesteld?
		my @defined = ("rft_id","item_id","tag");
		foreach my $defined(@defined){
			if(!(defined($params->{$defined}) && $params->{$defined} ne "")){
				push @{$response->{errors}},"PARAM_".uc($defined)."_MISSING";
			}
		}
		if(scalar(@{$response->{errors}})>0){
			$self->error($response);
			return;
		}
		#bestaat record?
		my $m_record = $self->db->load($rft_id);
		if(!defined($m_record)){
			push @{$response->{errors}},"RFT_ID_NONEXISTANT";
			$self->error($response);
			return;
		}
		#bestaat item?
		my $index_item = int($item_id) - 1;
		my $num = scalar(@{$m_record->{media}});
		if(!($index_item >= 0 && $index_item < $num)){
			push @{$response->{errors}},"ITEM_ID_NONEXISTANT";
			$self->error($response);
			return;
		}
		my $hits;
		my $totalhits;
		my $item_record = {};
		try{
			my $id = $rft_id."_".$item_id;
			($hits,$totalhits)=$self->tag_index->search("id:\"$id\"");
		};
		if(defined($totalhits) && $totalhits > 0){
			$item_record = clone($hits->[0]);
			$item_record->{tags} = [];
			push @{$item_record->{tags}},$_ foreach(split(' ',$hits->[0]->{tags}));
		}else{
			$item_record = {id=>$rft_id."_".$item_id,tags=>[]};
		}
		
		$response->{tags} = clone($item_record->{tags});
		$response->{rft_id} = $rft_id;
		$response->{item_id} = $item_id;
		my($success,$errors)=$self->validate_captcha($params);
		if($success){			
			$response->{success} = 1;
			#sla op
			my @old_tags = @{$item_record->{tags}};
			my @new_tags = split(' ',$tag);
			my %unique = ();
			$unique{$_}=1 foreach(@old_tags,@new_tags);
			$item_record->{tags} = join(' ',keys %unique);
			$self->tag_index->save($item_record);
			$self->send($response);
		}else{
			push @{$response->{errors}},"CAPTCHA_VALIDATION_FAILED";
			$self->error($response);
		}
	}elsif(defined($action) && $action eq "getkey"){
		$response->{success} = 1;
		$response->{captcha_html} = $self->captcha->get_html(Catmandu->conf->{all}->{captcha}->{public_key});
		$response->{public_key} = Catmandu->conf->{all}->{captcha}->{public_key};
		$self->send($response);
	}elsif(defined($action) && $action eq "gettags"){
		#parameters degelijk ingesteld?
                my @defined = ("rft_id","item_id");
                foreach my $defined(@defined){
                        if(!(defined($params->{$defined}) && $params->{$defined} ne "")){
                                push @{$response->{errors}},"PARAM_".uc($defined)."_MISSING";
                        }
                }
                if(scalar(@{$response->{errors}})>0){
                        $self->error($response);
                        return;
                }
		#bestaat record?
                my $m_record = $self->db->load($rft_id);
                if(!defined($m_record)){
                        push @{$response->{errors}},"RFT_ID_NONEXISTANT";
                        $self->error($response);
                        return;
                }
                #bestaat item?
                my $index_item = int($item_id) - 1;
                my $num = scalar(@{$m_record->{media}});
                if(!($index_item >= 0 && $index_item < $num)){
                        push @{$response->{errors}},"ITEM_ID_NONEXISTANT";
                        $self->error($response);
                        return;
                }
		#get tags
		my $tags = [];
		try{
			my($hits,$totalhits) = $self->tag_index->search("id:\"${rft_id}_${item_id}\"");
			$tags = $totalhits > 0 ? [split(' ',$hits->[0]->{tags})] : [];
			print "$_\n" foreach(@$tags);
		}catch{
			print $_;
		};
		$response->{success}=1;
		$response->{tags}=$tags;
		$self->send($response);
	}else{
		$response->{errors} = ["PARAM_ACTION_NOT_VALID"];
		$self->error($response);
	}
});
sub error {
	my($self,$response)=@_;
	$response->{captcha_html} = $self->captcha->get_html(Catmandu->conf->{all}->{captcha}->{public_key});
	$response->{public_key} = Catmandu->conf->{all}->{captcha}->{public_key};
	$self->send($response);
}
sub send {
	my($self,$response,$status_code)=@_;
	$self->response->content_type("application/json; charset=utf-8");
	print encode_json($response);
        $self->print(encode_json($response));
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

package PeepShow::cart::mail;
use Catmandu::App;

use parent qw(PeepShow::App::Common);

use Data::UUID;
use Digest::MD5 qw(md5_hex);
use JSON;
use MIME::Lite::TT::HTML;
use Email::Valid;

any([qw(get post)],'',sub{

	my $self = shift;

	#sessie
	my $sess = $self->request->session;		
	#parameters
	my $params = $self->request->parameters;
	my $action = $params->{action} // "";
        my $from = Catmandu->conf->{app}->{cart}->{email}->{from};
        my $to = $params->{to};
        my $message = $params->{message};

	my $response = {errors=>[]};
        #(fout)boodschappen

	my @defined = ("action","to","message");
	foreach(@defined){
		push @{$response->{errors}},"PARAM_".uc($_)."_NOT_DEFINED" if !(defined($params->{$_}) && $params->{$_} ne "");
	}
	if(scalar(@{$response->{errors}})>0){
		$self->send($response);
		return;
	}

	if($action eq "mail"){
                my($success,$errors) = $self->validate_captcha($params);
                push @{$response->{errors}},@$errors if !$success;
                push @{$response->{errors}},"PARAM_TO_NOT_VALID" if !Email::Valid->address($to);
                if(scalar(@{$response->{errors}})==0){
                        if(defined($sess->{devs}) && scalar(keys %{$sess->{devs}}) > 0){
                                #opslaan voor later gebruik..
                                my $newid = Data::UUID->new->create_str;
                                $self->snapshots->save({_id=>$newid,timestamp=>time,devs=>$sess->{devs}});
                                #..en een link opsturen naar kameraad naar deze snapshot
                                my $mime = MIME::Lite::TT::HTML->new(
                                        From => $from,
                                        To => $to,
                                        Subject => "GRIM",
                                        Template => {
                                                html => $self->template('sendmail_cart')
                                        },
                                        Charset     => 'utf8',
                                        TmplOptions => {INCLUDE_PATH=>Catmandu->home."/template"},
                                        TmplParams  =>  {from=>$from,to=>$to,link=>Catmandu->conf->{all}->{rooturl}."/mycart?action=load&id=$newid",message=>$message}
                                );
                                my $success = $mime->send(@{Catmandu->conf->{app}->{cart}->{email}->{params}});
                                if(!$success){
                                        push @{$response->{errors}},"SENDMAIL_FAILED";
                                }
                        }
                }
	}else{
		$response = {
                        errors => ["PARAM_ACTION_NOT_VALID"]
                };
	}
	$self->send($response);

});

sub snapshots {
	my $self = shift;
	$self->stash->{dbcarts} ||= $self->load_snapshots;
}
sub load_snapshots {
	my $self = shift;
	my $class = Catmandu->conf->{database}->{cart}->{class};
	Plack::Util::load_class($class);
	$class->new(%{Catmandu->conf->{database}->{cart}->{args}});
}
sub send {
        my($self,$response)=@_;
        $self->response->content_type("application/json; charset=utf-8");
        $self->print(encode_json($response));
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

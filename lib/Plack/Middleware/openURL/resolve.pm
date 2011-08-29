package Plack::Middleware::openURL::resolve;
use strict;
use utf8;
use parent qw(Plack::Middleware);
use Plack::App::Proxy;
use openURL::resolve;
use Try::Tiny;
use Catmandu;
use HTTP::Date;

my $proxy = Plack::App::Proxy->new->to_app;
my $handler = openURL::resolve->new();
my $openurl_path = Catmandu->conf->{middleware}->{openURL}->{path} || "/openURL";
my $resolve_path = Catmandu->conf->{middleware}->{openURL}->{resolve}->{path} || "/resolve";
my $openurl_resolve_path = $openurl_path.$resolve_path;
my $x_send_expire = Catmandu->conf->{middleware}->{openURL}->{resolve}->{expire} || 3600;

sub call {
        my($self,$env)=@_;
        my $path = $env->{PATH_INFO};
        my $res;
        if($path eq $openurl_resolve_path){
                my %params = map {split '=',$_} split /&(amp;)?/,$env->{QUERY_STRING};
		utf8::decode($params{$_}) foreach(keys %params);
                my $rft_id = $params{rft_id};
                my $svc_id = lc $params{svc_id};
                delete $params{rft_id};
                delete $params{svc_id};

                my($hash,$template,$code,$err)=$handler->handle({rft_id => $rft_id,svc_id=>$svc_id},$env);
                if(defined($err)){
                        $res = $self->response_error($code,$err);
                }
                elsif(defined($template)){
                        my $body;
                        my $e;
                        try{
                                Catmandu->print_template($template,{hash=>$hash},\$body);
				utf8::encode($body);
                        }catch{
                                $e = $_;
                        };
                        if(defined($e)){
                                $res = $self->response_error(500,$e);
                        }else{
                                $res = [$code,['Content-Type'=>'text/html'],[$body]];
                        }
                }else{
                        $env->{$_->{key}} = $_->{value} foreach(@{$hash->{env}});
                        if(defined($env->{'plack.proxy.url'})){
                                $res = $proxy->($env);
                        }elsif(defined($env->{'plack.xsend.url'})){
                                $res = [$code,[
                                                'X-Accel-Redirect' => $env->{'plack.xsend.url'},
                                                'X-Sendfile' => $env->{'plack.xsend.url'},
						'X-Accel-Buffering'=>'yes',
						'X-Accel-Expires' => $x_send_expire,
                                                'Expires' => time2str(time+$x_send_expire)
                                ],[]];
                        }elsif(defined($env->{'plack.redirect.url'})){
				$res = [$code,['Location'=>$env->{'plack.redirect.url'}],[]];
			}elsif(defined($env->{'plack.body'}) && defined($env->{'plack.content_type'})){
				$res = [$code,['Content-Type' => $env->{'plack.content_type'}],[$env->{'plack.body'}]];
			}
			else{
                                $res = $self->response_error('500','invalid action');
                        }
                }
        }else{
                $res = $self->app->($env);
        }
        $res;
}
sub response_error {
        my($self,$code,$err)=@_;
	my $body = [];
	if($code != 401){
	        push @$body,"<html><head><title>$err</title></head><body><table style='border:1px solid black'><tr><th>error in openURL:</th><td>$err</td></tr></table></body></html>";
	}else{
		push @$body,"access denied";
	}
        return [$code,['Content-Type'=>'text/html'],$body];
}

1;

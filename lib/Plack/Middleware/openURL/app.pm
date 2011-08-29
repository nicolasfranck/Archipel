package Plack::Middleware::openURL::app;
use strict;
use utf8;
use parent qw(Plack::Middleware);
use openURL::app;
use Try::Tiny;
use Catmandu;

my $handler = openURL::app->new();
my $openurl_path = Catmandu->conf->{middleware}->{openURL}->{path} || "/openURL";
my $app_path = Catmandu->conf->{middleware}->{openURL}->{app}->{path} || "/app";
my $openurl_app_path = $openurl_path.$app_path;

sub call {
        my($self,$env)=@_;
        my $path = $env->{PATH_INFO};
        my $res;
        if($path eq $openurl_app_path){
                my %params = map {split '=',$_} split /&(amp;)?/,$env->{QUERY_STRING};
		utf8::decode($params{$_}) foreach(keys %params);
                my $id = $params{id};
                my $type = lc $params{type};
                delete $params{id};
                delete $params{type};
	
                my($hash,$template,$code,$err)=$handler->handle({id => $id,type=>$type},$env);
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
                }
        }else{
                $res = $self->app->($env);
        }
        $res;
}
sub response_error {
        my($self,$code,$err)=@_;
	my $body = [];
	push @$body,"<html><head><title>$err</title></head><body><table style='border:1px solid black'><tr><th>error in openURL:</th><td>$err</td></tr></table></body></html>";
        return [$code,['Content-Type'=>'text/html'],$body];
}

1;

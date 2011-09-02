#!/usr/bin/perl
use Plack::Builder;
use Plack::Session::Store::File;

use PeepShow::search::all;
use PeepShow::search::view;
use PeepShow::admin;
use PeepShow::rss;
use PeepShow::xml;
use PeepShow::json;
use PeepShow::mycart;
use PeepShow::cart;
use PeepShow::googlemaps;
use PeepShow::facet;
use PeepShow::videostreaming::external;

use Catmandu;
use Digest::MD5 qw(md5_hex);
use Catmandu;
use Digest::MD5 qw(md5_hex);
use File::Path qw(mkpath);
use File::Basename qw(dirname);

#tests
my $session_dir = Catmandu->conf->{all}->{session}->{store}->{dir};
if(!-d $session_dir){
        if(!mkpath($session_dir)){
                print STDERR "could not create session directory $session_dir\n";
                exit 1;
        }
}elsif(!-w $session_dir){
        print STDERR "$session_dir is not writable\n";
        exit 1;
}
my $cache_file = Catmandu->conf->{middleware}->{openURL}->{resolve}->{cache}->{args}->{share_file};
my $cache_dir = dirname($cache_file);
if(!-d $cache_dir){
        if(!mkpath($cache_dir)){
                print STDERR "could not create cache directory $cache_dir\n";
                exit 1;
        }
}elsif(!-w $cache_dir){
        print STDERR "cache dir $cache_dir is not writable\n";
        exit 1;
}
elsif(-f $cache_file && !-w $cache_file){
        print STDERR "cache file $cache_file, but is not writable\n";
        exit 1;
}


builder{
	#middleware
	enable 'Session',store=>Plack::Session::Store::File->new(dir=> '/tmp/sessions/archipel');
	enable "Static", path => qr{^/(images|js|css|flash)/} , root => 'htdocs/';
	enable 'openURL::resolve';
	enable 'openURL::app';
	#routes
	mount "/",PeepShow::search::all->to_app;
	mount "/view",PeepShow::search::view->to_app;
	mount "/rss",PeepShow::rss->to_app;
	mount "/xml",PeepShow::xml->to_app;
	mount "/json",PeepShow::json->to_app;
	mount "/mycart",PeepShow::mycart->to_app;
	mount "/cart",PeepShow::cart->to_app;
	mount "/googlemaps",PeepShow::googlemaps->to_app;
	mount "/facet",PeepShow::facet->to_app;
	mount "/videostreaming/external",PeepShow::videostreaming::external->to_app;
	mount "/admin" => builder {
		enable 'Auth::Basic',authenticator=>sub{
			my($username,$password)=@_;
			return $username eq Catmandu->conf->{app}->{admin}->{auth}->{username} && md5_hex($password) eq Catmandu->conf->{app}->{admin}->{auth}->{password};
		};
		PeepShow::admin->to_app;
	};
};

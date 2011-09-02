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

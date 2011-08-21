#!/usr/bin/perl
use Plack::Builder;
use PeepShow::search::all;
use PeepShow::search::view;
use PeepShow::admin;
use PeepShow::rss;
use PeepShow::xml;
use PeepShow::mycart;
use PeepShow::cart;
use PeepShow::googlemaps;
use PeepShow::tag;
use Catmandu;

use Digest::MD5 qw(md5_hex);

builder{
	#middleware
	enable 'Session';
	enable "Static", path => qr{^/(images|js|css|flash)/} , root => 'htdocs/';
	enable 'openURL';
	#routes
	mount "/",PeepShow::search::all->to_app;
	mount "/view",PeepShow::search::view->to_app;
	mount "/rss",PeepShow::rss->to_app;
	mount "/xml",PeepShow::xml->to_app;
	mount "/mycart",PeepShow::mycart->to_app;
	mount "/cart",PeepShow::cart->to_app;
	mount "/googlemaps",PeepShow::googlemaps->to_app;
	mount "/tag",PeepShow::tag->to_app;
	mount "/admin" => builder {
		enable 'Auth::Basic',authenticator=>sub{
			my($username,$password)=@_;
			return $username eq Catmandu->conf->{app}->{admin}->{auth}->{username} && md5_hex($password) eq Catmandu->conf->{app}->{admin}->{auth}->{password};
		};
		PeepShow::admin->to_app;
	};
};

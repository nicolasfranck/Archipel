#!/usr/bin/perl
use Plack::Builder;
use Plack::Session::Store::File;
use PeepShow::search_all;
use PeepShow::search_view;
use PeepShow::admin;
use PeepShow::rss;
use PeepShow::xml;
use PeepShow::mycart;
use PeepShow::cart;
use PeepShow::googlemaps;
use Catmandu;

builder{
	#middleware
	#enable 'Session',store=>Plack::Session::Store::File->new(dir=> '/tmp/sessions/peepshow');
	enable 'Session';
	enable "Static", path => qr{^/(images|js|css|flash)/} , root => 'htdocs/';
	enable 'openURL';
	#routes
	mount "/",PeepShow::search_all->to_app;
	mount "/view",PeepShow::search_view->to_app;
	mount "/rss",PeepShow::rss->to_app;
	mount "/xml",PeepShow::xml->to_app;
	mount "/mycart",PeepShow::mycart->to_app;
	mount "/cart",PeepShow::cart->to_app;
	mount "/googlemaps",PeepShow::googlemaps->to_app;
	mount "/admin" => builder {
		enable 'Auth::Basic',authenticator=>sub{
			my($username,$password)=@_;
			return $username eq Catmandu->conf->{Columns}->{auth}->{username} && $password eq Catmandu->conf->{Columns}->{auth}->{password};
		};
		PeepShow::admin->to_app;
	};
};

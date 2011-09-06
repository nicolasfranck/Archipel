package openURL::Service::Image::Size;
use strict;
use Data::Validate::URI qw(is_web_uri);
use Catmandu;

my $ip = Catmandu->conf->{all}->{ip};
my $rootexp = qr/^http:\/\/$ip(.*)/;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;
        my $file = $record->{media}->[$opts->{item_id} - 1]->{devs}->{$opts->{svc_id}};
        my $key;
        my $value;
        if(not defined($file)){
		return {
			env => [{key=>'plack.xsend.url',value=>'/notfound/image_not_available.jpg'}]
		},200,undef;
        }
	if($file->{no_proxy}){
		return {env=>[{
			key => 'plack.redirect.url',
			value => $file->{url}
		}]},302,undef;
	}
	$file->{url} =~ s/localhost/127.0.0.1/;
	# http://50.17.222.182/thumbies/mijnfoto.jpeg
        if(is_web_uri($file->{url})){
                if($file->{url} !~ $rootexp){
                        $key = 'plack.xsend.url';
                        $value = '/external/'.$file->{url};
                }else{
                        $key = 'plack.xsend.url';
                        $value = $1;
                }
        }	
	# /thumbies/mijnfoto.jpeg
	else{
                $key = 'plack.xsend.url';
                $value = $file->{url};
        }
        return {
                env => [
                        {
                                key => $key,
                                value => $value
                        }
                ]
        },200,undef;
}

1;

package openURL::Service::Image::Size;
use strict;
use Data::Validate::URI qw(is_web_uri);
use Catmandu;

my $ip = Catmandu->conf->{all}->{ip};
my $rootexp = qr/^http:\/\/$ip(.*)/;
my $localhost = qr/^http:\/\/127\.0\.0\.1(.*)/;

sub new {
	bless {},shift;
}
sub handle{
	my($self,$opts,$record)=@_;
        my $file = $record->{media}->[$opts->{item_id} - 1]->{devs}->{$opts->{svc_id}};
        my $key;
        my $value;
	my $context = $record->{media}->[$opts->{item_id} - 1]->{context};
	#geen file gedefiniëerd
        if(not defined($file)){
		return {
			env => [{
				key => 'plack.xsend.url',
				value=> Catmandu->conf->{middleware}->{openURL}->{resolve}->{context}->{$context}->{$opts->{svc_id}}->{MissingImage}->{url}
			}]
		},302,undef;
        }
	#lokale file, maar extern getest
	if($file->{path} && !-f $file->{path}){
		return {
                        env => [{
                                key => 'plack.xsend.url',
                                value=> Catmandu->conf->{middleware}->{openURL}->{resolve}->{context}->{$context}->{$opts->{svc_id}}->{MissingImage}->{url}
                        }]
                },302,undef;
	}
	#externe file, geen path
	$file->{url} =~ s/localhost/127.0.0.1/;
	# http://50.17.222.182/thumbies/mijnfoto.jpeg
        if(is_web_uri($file->{url})){
                if($file->{url} !~ $rootexp && $file->{url} !~ $localhost){
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

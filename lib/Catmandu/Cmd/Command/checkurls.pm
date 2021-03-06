package Catmandu::Cmd::Command::checkurls;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
use Data::Validate::URI qw(is_web_uri);
use LWP::UserAgent;
with qw(
        Catmandu::Cmd::Opts::Grim::Store::Media
        Catmandu::Cmd::Opts::Grim::Exif::Image
);
use Catmandu::Store::Simple;

has _media => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                Catmandu::Store::Simple->new(%{shift->media_arg});
        }
);
has _ua => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		LWP::UserAgent->new();	
	}
);
sub check{
	my($self,$url,$content_type)=@_;
	#absoluut of relatief?
	my $response = $self->_ua->head($url);
	return{
		exists => $response->is_success,
		content_type_valid => $response->content_type eq $content_type
	};
}

sub execute{
        my($self,$opts,$args)=@_;

	#useragent
	$self->_media->each(sub{
                my $record = shift;
                my $files = {_id=>$record->{_id},valid=>[],err=>[]};
                #files
                foreach my $item(@{$record->{media}}){
                        #files
                        foreach my $file(@{$item->{file}}){
                                if(defined($file->{url})){
                                        my $res = $self->check($file->{url},$file->{content_type});
                                        if($res->{exists} && $res->{content_type_valid}){
                                                 print $file->{url}." [url OK,content_type VALID]\n";
                                        }else{
                                                print $file->{url}." [url ";
						if(not $res->{exists}){
							print "NOT OK";
						}else{
							print "OK"
						}
						print ",content_type ";
						if(not $res->{content_type_valid}){
                                                        print "NOT VALID";
                                                }else{
                                                        print "VALID"
                                                }
						print "]\n";
                                        }
                                }
                        }
                        #thumbs
                        foreach my $svc_id(%{$item->{devs}}){
                                my $url = $item->{devs}->{$svc_id}->{url};
                                my $content_type = $item->{devs}->{$svc_id}->{content_type};
                                if(defined($url)){
                                        my $res = $self->check($url,$content_type);
                                        if($res->{exists} && $res->{content_type_valid}){
                                                 print "$url [url OK,content_type VALID]\n";
                                        }else{
                                                print "$url [url ";
                                                if(not $res->{exists}){
                                                        print "NOT OK";
                                                }else{
                                                        print "OK"
                                                }
                                                print ",content_type ";
                                                if(not $res->{content_type_valid}){
                                                        print "NOT VALID";
                                                }else{
                                                        print "VALID"
                                                }
                                                print "]\n";
                                        }
			
                                }
                        }
                }
        });
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

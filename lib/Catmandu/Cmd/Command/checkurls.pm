package Catmandu::Cmd::Command::checkurls;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;
use Data::Validate::URI qw(is_web_uri);

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
use LWP::UserAgent;

has storetype => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 's',
    documentation => "Type of store [default:Simple]",
        default => sub{"Simple";}
);

has db_args => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]",
        required => 1
);

has ua => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		LWP::UserAgent->new();	
	}
);
sub check{
	my($self,$url,$content_type)=@_;
	#absoluut of relatief?
	my $response = $self->ua->head($url);
	return{
		exists => $response->is_success,
		content_type_valid => $response->content_type eq $content_type
	};
}


sub execute{
        my($self,$opts,$args)=@_;

	#databank
	my $class = "Catmandu::Store::".$self->storetype;
        Plack::Util::load_class($class) or die();
        my $store = $class->new(%{$self->db_args});
	#useragent
	my $ua = LWP::UserAgent->new();
	$store->each(sub{
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

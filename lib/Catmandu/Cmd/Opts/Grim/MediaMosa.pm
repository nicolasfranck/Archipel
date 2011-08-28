package Catmandu::Cmd::Opts::Grim::MediaMosa;
our $VERSION = 0.01;# VERSION
use Moose::Role;
use Try::Tiny;
use XML::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use Digest::SHA1 qw(sha1_hex);
use Data::UUID;
use URI::Escape;
use Term::ReadKey;

has yaml_mediamosa_arg => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'ym',
	documentation => "YAML configuration for mediamosa (default $ENV{HOME}/PeepShow/maps/aleph-mediamosa.yml)",
	default => sub{
		$ENV{HOME}."/PeepShow/maps/aleph-mediamosa.yml";
	}
);
has _yaml_mediamosa => (
        is =>'ro',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                my $hash;
                try{
                        $hash = YAML::LoadFile($self->yaml_mediamosa_arg);
                }catch{
                        warn $_;
                        $hash = {};
                };
                $hash;
        }
);
has _ua => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		LWP::UserAgent->new(cookie_jar=>{});
	}
);
has _xml_parser => (
	is => 'rw',
	isa => 'Ref',
	default => sub {
		XML::Simple->new;
	}
);
has mediamosa_arg => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'HashRef',
        cmd_aliases => 'm',
        documentation => "mediamosa parameters (username,baseurl)",
	default => sub {
		{
			username => 'grim',
			baseurl => 'http://edepot-app1.archipel-project.be',
			oai_id2asset_id => '^oai:archipel-project\.be:(\w+)$'
		};
	}
);
has _last_password => (
        is => 'rw',
        isa => 'Str|Undef',
);
has _oai_id2asset_id => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		my $self = shift;
		my $re = $self->mediamosa_arg->{oai_id2asset_id};
		return qr/$re/;
	}	
);
sub get_password {
	my $self = shift;
	my $password;
	while(!(defined($password) && $password ne "")){
		print "enter mediamosa password:";
		ReadMode('noecho');
		$password = ReadLine(0);
		chomp $password;
		ReadMode('normal');
		print "\n";
	}
	return $password;
}
sub logout {
	shift->_last_password(undef);
}
sub login {
	my $self = shift;
	
	my $username = $self->mediamosa_arg->{username};
	my $baseurl = $self->mediamosa_arg->{baseurl};
	my $dbus;
	my $xml_response = {};
	
	print "authenticating..\n";
	my $password = $self->get_password;

	#challenge
	$dbus = "AUTH DBUS_COOKIE_SHA1 $username";
	my $response = $self->_ua->get("$baseurl/login?dbus=$dbus");
	if(!$response->is_success){
		return 0,$response->content;
	}
	$xml_response = $self->_xml_parser->XMLin($response->content);
	if($xml_response->{header}->{request_result} eq "error"){
		return 0,"error: ".$xml_response->{header}->{request_result_description};
	}
	if(!defined($xml_response->{items}->{item}->{dbus})){
		return 0,"error: could not find dbus answer in response";
	}
	$xml_response->{items}->{item}->{dbus} =~ /^DATA vpx 0 (\w+)$/;
	my $challenge = $1;

	#response
	my $random = Data::UUID->new->create_str;
	my $res_str = sha1_hex("$challenge:$random:$password");
	$dbus = "DATA $random $res_str";
	$response = $self->_ua->get("$baseurl/login?dbus=$dbus");
	if(!$response->is_success){
                return 0,$response->content;
        }
        $xml_response = $self->_xml_parser->XMLin($response->content);

	#ingelogd?
	$dbus = $xml_response->{items}->{item}->{dbus};
	if($dbus !~ /OK/){
		return 0,"error:$dbus";
	}
	print "successfully logged in!\n";
	$self->_last_password($password);
	return 1;
}
sub get_asset {
	my($self,$oai_id)=@_;
	my $asset;
	print "in function get_asset\n";
	if($oai_id !~ $self->_oai_id2asset_id){
		return undef,"oai_id_invalid";	
	}	
	my $asset_id = $1;
	#algemeen
	my $baseurl = $self->mediamosa_arg->{baseurl};
	my $response;
	my $xml_response;
	
	#haal asset op (mediafiles en stilstaande beelden zijn altijd inbegrepen)
        $response = $self->_ua->get("$baseurl/asset/$asset_id");
        return undef,$response->content if not $response->is_success;
        $xml_response = $self->_xml_parser->XMLin($response->content);
        return undef,$xml_response->{header}->{request_result_description} if ($xml_response->{header}->{request_result_description} eq "error");
        return undef,$xml_response->{header}->{request_result_description} if $xml_response->{header}->{item_count_total} eq '0';
	$asset = $xml_response->{items}->{item};
	if(ref $asset->{mediafiles} eq "HASH"){
		$asset->{mediafiles} = [$asset->{asset}->{mediafiles}];	
	}
	return $asset,undef;	
}
no Moose::Role;
1;

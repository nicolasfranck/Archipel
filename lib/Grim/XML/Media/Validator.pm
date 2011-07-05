package Grim::XML::Media::Validator;
use Moose;
use XML::Validator::Schema;
use XML::SAX::ParserFactory;
use Try::Tiny;

has _parser => (
	is => 'ro',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		my $self = shift;
		my $validator = XML::Validator::Schema->new(file => "media.xsd");
	        XML::SAX::ParserFactory->parser(Handler=>$validator);
	}
);
sub is_valid {
	my($self,$file) = @_;
	my $err = undef;
	try{
		$self->_parser->parse_uri($file);
	}catch{
		$err = $_;
	};
	return (!defined($err),$err);
}



no Moose;
1;

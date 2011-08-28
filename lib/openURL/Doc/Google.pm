package PeepShow::Handler::Service::Doc::Google;
use URI::Escape;
use Moose;

has _googleDocsURL => (
	is => 'ro',
	isa => 'Str',
	default => sub{
		return 'http://books.google.com/books';
	}
);

sub handle{
    my($self,$info,$record)=@_;
    my $url = $record->{file}->[0]->{url};
	my $path = $self->_googleDocsURL."?id=".uri_escape($url)."&printsec=frontcover&cd=1&source=gbs_ViewAPI&output=embed#%257B%2522showLinkChrome%2522%253Afalse%257D";	
	return {
		link => $path
	},undef;
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

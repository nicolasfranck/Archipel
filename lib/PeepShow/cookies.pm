package PeepShow::cookies;
use utf8;
use Catmandu::App;
use Data::Dumper;

#binmode(STDOUT,":encoding(UTF-8)");
any([qw(get post head)],'/',sub{
        my $self = shift;
	print Dumper($self->request->cookies);
	my $cookies = $self->response->cookies($self->request->cookies);	
	open FILE,">/home/nicolas/output.data" or die($!);
	foreach(keys %$cookies){
		print "$_ : $cookies->{$_}\n";
		print FILE "$_ : $cookies->{$_}\n";
		print utf8::valid($cookies->{$_}) ? "valid\n":"is not valid\n";
	}
	close FILE;
});

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

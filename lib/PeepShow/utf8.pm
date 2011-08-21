package PeepShow::utf8;
use utf8;
use Catmandu::App;

use Data::Dumper;
use Try::Tiny;
use Catmandu::Index::Solr;

any([qw(get post)],'/',sub{
        my $self = shift;
	$self->response->content_type("text/plain; charset=utf-8");
	my $index = Catmandu::Index::Solr->new(url=>"http://localhost:8983/solr/core1",id_field=>"id");
	try{
		my($hits,$totalhits)=$index->search("*");
		return unless $totalhits;
		foreach my $hit(@$hits){
			foreach(keys %$hit){
				my $s = sprintf("%10s : %s\n",$_,$hit->{$_});
				$self->print($s);
				print utf8::valid($hit->{$_})?"valid\n":"not valid\n";
			}
		
		}
	}catch{
		print $_;
	};
});

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

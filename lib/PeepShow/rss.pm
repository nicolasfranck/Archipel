package PeepShow::rss;
use Catmandu::App;
use Plack::Util;
use Data::Pageset;
use PeepShow::Resolver::DB;
use XML::RSS;
use List::MoreUtils qw(first_index);
use PeepShow::Handler::Query::Parser;

any([qw(get post )],'',sub{
	my $self = shift;
	my $params = $self->request->parameters;

	#parameters
	my($q,$opts) = $self->query_parser->parse($params);

	#opzoeken
	my($hits,$totalhits,$err)=$self->db->query_store($q,%$opts);
	if($totalhits > 0){
		#start RSS
	        my $rss = XML::RSS->new(version=>'2.0');
        	#namespaces
	        $rss->add_module(%$_) foreach(@{$self->namespaces});
        	#channel
	        $rss->channel(
        	        title => "$q - Universiteitsbibliotheek - GRIM",
                	link => $self->rooturl."?q=$q",
	                description => "Zoekresultaten voor \"$q\" in de GRIM",
			"opensearch" => {
        	        	"totalResults" => $totalhits,
				"startIndex" => 1,
				"itemPerPage" => 10,
				"Query" => {"role" => "request",searchTerms=>$q}
			}
	        );
		foreach my $hit(@$hits){
			my $contexts = {};
			foreach my $item(@{$hit->{media}}){
        	 	       $contexts->{$item->{context}}++;
	        	}
			my $context_description = join ',',map {lc($_)."s (".lc($contexts->{$_}).")"} keys %$contexts;
			$rss->add_item(
				title=> $hit->{title}->[0],
				link => $self->rooturl."/view?q=".$hit->{_id},
				guid => $hit->{_id},
				enclosure => {
					url => $self->rooturl."/OpenURL/resolve?rft_id=".$hit->{_id}.":1&svc_id=thumbnail&url_ver=".$self->openURL->{version},
					length => $hit->{media}->[0]->{devs}->{thumbnail}->{size},
					type => $hit->{media}->[0]->{devs}->{thumbnail}->{content_type}
				},
				description => $context_description
			);
		}
		$self->print($rss->as_string);

	}
});
sub db {
	shift->stash->{db} ||= PeepShow::Resolver::DB->new();
}

sub rooturl{
	Catmandu->conf->{rooturl};
}
sub openURL {
        Catmandu->conf->{openURL};
}
sub sort_fields{
        my $self = shift;
        my $language = $self->language;
        return Catmandu->conf->{DB}->{index}->{sort_fields};
}
sub namespaces {
	Catmandu->conf->{RSS}->{namespaces};
}
sub query_parser {
        shift->stash->{query_parser}||=PeepShow::Handler::Query::Parser->new();
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

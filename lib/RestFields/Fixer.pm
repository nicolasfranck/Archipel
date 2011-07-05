package RestFields::Fixer;
use Clone qw(clone);

sub new {
	bless {},shift;
}
sub fix {
	my($self,$rest)=@_;
	$rest = clone($rest);
#	 'facet_counts' => {
#                              'facet_fields' => {
#                                                  'context' => [
#                                                                 'Image',
#                                                                 0
#                                                               ]
#                                                },
#                              'facet_dates' => {},
#                              'facet_queries' => {}
#                            }
#        };
	return {} if ref($rest) ne "HASH";
	if(defined($rest->{facet_counts})){
		my $fields = {};
		foreach my $key(keys %{$rest->{facet_counts}->{facet_fields}}){
			$fields->{$key} = {};
			%{$fields->{$key}} = @{$rest->{facet_counts}->{facet_fields}->{$key}};
		}
		$rest->{facet_counts}->{facet_fields} = $fields;
	}
#	'spellcheck' => {
#                            'suggestions' => [
#                                               'Sant',
#                                               {
#                                                 'startOffset' => 0,
#                                                 'endOffset' => 4,
#                                                 'suggestion' => [
#                                                                   'Sint'
#                                                                 ],
#                                                 'numFound' => 1
#                                               }
#                                             ]
#                          }
	if(defined($rest->{spellcheck})){
		my $h = {};
		foreach my $key(keys %{$rest->{spellcheck}}){
			$h->{$key} = {};
			%{$h->{$key}} = @{$rest->{spellcheck}->{$key}};
		}	
		$rest->{spellcheck} = $h;
	}
	return $rest;
}	

1;

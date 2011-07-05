package Record::View::Pages;
use Catmandu;
use PeepShow::Tools::Record;
use Data::Pageset;
use POSIX qw(ceil floor);
use parent qw(Record::View);

sub prepare{
	my $self = shift;

        #voor het geval men terug wil keren naar de zoekweergave -> op welke pagina moeten we dan terecht komen?
        #zeker wanneer men de links 'eerste','vorige','volgende' en 'laatste' heeft gewerkt
        my $num = $self->sess->{num} || Catmandu->conf->{DB}->{index}->{num_default};
        my $start = (defined($self->params->{start}) && $self->params->{start} ne "")? $self->params->{start} : 0;
        $self->sess->{page} = floor($start / $num) + 1;
        $self->sess->{num} = $num;

	#pagineren van items op view 'pages'
	$self->args->{pages_per_set}=Catmandu->conf->{DB}->{index}->{pages_per_set};
	$self->args->{entries_per_page}=$self->params->{numitems} || Catmandu->conf->{DB}->{index}->{num_default};
	my $page = $self->params->{page};
	$self->params->{page}=($page && $page > 0 && $page =~ /^\d+$/)? $page:1;
	$start = ($self->params->{page} - 1)*$self->args->{entries_per_page};

        my $poster_index = $self->record->{poster_item_id} - 1;
        $self->args->{poster} = (defined($self->record->{media}->[0]->{devs}->{small}->{url}))? $self->record->{media}->[$poster_index]->{devs}->{small}->{url}:$self->record->{media}->[$poster_index]->{devs}->{thumbnail}->{url};
        $self->args->{total_items} = scalar(@{$self->record->{media}});
        my $contexts={};
        foreach my $item(@{$self->record->{media}}){
                $contexts->{$item->{context}}++;
        }
        $self->args->{contexts} = $contexts;
        $self->args->{rft_id} = $self->record->{_id};
        $self->args->{item_id} = $self->args->{item_id};

	#filter op context
	if($self->args->{context}){
        	$self->record->{media} = filter($self->record->{media},{'context'=>$self->args->{context}});
	}

        #pas total_items aan het gefilterde resultaat
        $self->args->{total_items} = scalar(@{$self->record->{media}});

        #slice
        $self->record->{media}=slice($self->record->{media},$start,$self->args->{entries_per_page});

	#pagineer                       
        my $page_info = Data::Pageset->new({
        	'total_entries'       => $self->args->{total_items},
                'entries_per_page'    => $self->args->{entries_per_page},
                'current_page'        => $self->params->{page},
                'pages_per_set'       => $self->args->{pages_per_set},
                'mode'                => 'fixed'
       	});
	$self->args->{hit}=$self->record;
        $self->args->{begin_item}=$start+1;
        $self->args->{end_item}=  $start+scalar(@{$self->record->{media}});
        $self->args->{first_page}=$page_info->first_page;
        $self->args->{last_page}=$page_info->last_page;
        $self->args->{current_page}=$page_info->current_page;
        $self->args->{previous_page}=$page_info->previous_page;
        $self->args->{next_page}=$page_info->next_page;
        $self->args->{pages_in_set}=$page_info->pages_in_set;
}

1;

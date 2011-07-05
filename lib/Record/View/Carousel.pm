package Record::View::Carousel;
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

        #pagineren van items op view 'carousel'
        $self->args->{pages_per_set}=Catmandu->conf->{DB}->{index}->{pages_per_set};
        $self->args->{entries_per_page}=$self->params->{num} || Catmandu->conf->{DB}->{index}->{num_default};
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
	$self->args->{item_id} = $self->params->{item_id} // 1;
	my $index_item = $self->args->{item_id} - 1;
	if(not defined($self->record->{media}->[$index_item])){
		my $errmsg = $self->args->{rft_id}." en ".$self->args->{item_id}." niet teruggevonden";
        	$self->args->{errmsg}= $errmsg;
		$self->errmsg($errmsg);
        }else{
		#offset van de set van buren
                my $count_offset = floor(($self->args->{item_id} - 1) / $self->args->{entries_per_page})*$self->args->{entries_per_page};
                #vorige en volgende set van buren
                my $first_set = 1;
                my $prev_set = (defined($self->record->{media}->[$count_offset - 1]))? $count_offset:undef;
                my $next_set = (defined($self->record->{media}->[$count_offset+$self->args->{entries_per_page}+1]))? $count_offset+$self->args->{entries_per_page}+1:undef;
                my $last_set = scalar(@{$self->record->{media}});
                #en kappen maar                                 
                $self->record->{media}=slice($self->record->{media},$count_offset,$self->args->{entries_per_page});

                #en waar zat die ook weer? -> positie van item onder zijn soortgenoten..
                $index_item = ($self->args->{item_id} - 1) % $self->args->{entries_per_page};                                             
                $self->args->{hit}=$self->record;
                $self->args->{index_item}=$index_item;
                $self->args->{first_set}=$first_set;
                $self->args->{prev_set}=$prev_set;
                $self->args->{next_set}=$next_set;
                $self->args->{last_set}=$last_set;
	}
}

1;

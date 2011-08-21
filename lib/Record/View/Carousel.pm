package Record::View::Carousel;
use Catmandu;
use PeepShow::Tools::Record;
use Data::Pageset;
use POSIX qw(ceil floor);
use parent qw(Record::View);

sub prepare{
	my $self = shift;

        #voor het geval men terug wil keren naar de zoekweergave -> op welke pagina moeten we dan terecht komen?
        #zeker wanneer men de links 'eerste','vorige','volgende' en 'laatste' heeft gewerkt
        my $num = $self->sess->{num} || Catmandu->conf->{app}->{search}->{num_default};
        my $start = (defined($self->params->{start}) && $self->params->{start} ne "")? $self->params->{start} : 0;
        $self->sess->{page} = floor($start / $num) + 1;
        $self->sess->{num} = $num;

        #pagineren van items op view 'carousel'
        $self->args->{pages_per_set}=Catmandu->conf->{app}->{search}->{pages_per_set};
        $self->args->{entries_per_page}=$self->params->{num} || Catmandu->conf->{app}->{search}->{num_default};
        my $page = $self->params->{page};
        $page=($page && $page > 0 && $page =~ /^\d+$/)? $page:1;
	$self->params->add(page=>$page);
       	$start = ($self->params->{page} - 1)*$self->args->{entries_per_page};
        my $poster_index = $self->args->{hit}->{poster_item_id} - 1;
        $self->args->{poster} = (defined($self->args->{hit}->{media}->[0]->{devs}->{small}->{url}))? $self->args->{hit}->{media}->[$poster_index]->{devs}->{small}->{url}:$self->args->{hit}->{media}->[$poster_index]->{devs}->{thumbnail}->{url};
        $self->args->{total_items} = scalar(@{$self->args->{hit}->{media}});

        my $contexts={};
        foreach my $item(@{$self->args->{hit}->{media}}){
                $contexts->{$item->{context}}++;
        }
        $self->args->{contexts} = $contexts;
        $self->args->{rft_id} = $self->args->{hit}->{_id};
	$self->args->{item_id} = $self->params->{item_id} // 1;
	my $index_item = $self->args->{item_id} - 1;
	if(not defined($self->args->{hit}->{media}->[$index_item])){
		my $errmsg = $self->args->{rft_id}." en ".$self->args->{item_id}." niet teruggevonden";
        	$self->args->{errmsg}= $errmsg;
		$self->errmsg($errmsg);
        }else{
		#offset van de set van buren
                my $count_offset = floor(($self->args->{item_id} - 1) / $self->args->{entries_per_page})*$self->args->{entries_per_page};
                #vorige en volgende set van buren
                my $first_set = 1;
                my $prev_set = (defined($self->args->{hit}->{media}->[$count_offset - 1]))? $count_offset:undef;
                my $next_set = (defined($self->args->{hit}->{media}->[$count_offset+$self->args->{entries_per_page}+1]))? $count_offset+$self->args->{entries_per_page}+1:undef;
                my $last_set = scalar(@{$self->args->{hit}->{media}});
                #en kappen maar                                 
                $self->args->{hit}->{media}=slice($self->args->{hit}->{media},$count_offset,$self->args->{entries_per_page});

                #en waar zat die ook weer? -> positie van item onder zijn soortgenoten..
                $index_item = ($self->args->{item_id} - 1) % $self->args->{entries_per_page};                                             
                $self->args->{index_item}=$index_item;
                $self->args->{first_set}=$first_set;
                $self->args->{prev_set}=$prev_set;
                $self->args->{next_set}=$next_set;
                $self->args->{last_set}=$last_set;
		$self->args->{carousel}->{mapping} = Catmandu->conf->{service_aggregate}->{carousel}->{mapping};
	}
}

1;

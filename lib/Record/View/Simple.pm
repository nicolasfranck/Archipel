package Record::View::Simple;
use Catmandu;
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
	#$self->record->{media}=[];
	$self->args->{hit}=$self->record;
}

1;

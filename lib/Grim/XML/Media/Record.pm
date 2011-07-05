package Grim::XML::Media::Record;
use Moose;
use Grim::XML::Media::Record::Item;
use Clone qw(clone);

has id => (
        is => 'rw',
        isa => 'Str|Undef',
        required => 0,
);
has items => (
        is => 'rw',
        isa => 'ArrayRef[Grim::XML::Media::Record::Item]',
        required => 0,
        default => sub{[]}
);
has poster_item_id => (
        is => 'rw',
        isa => 'Int',
        required => 0,
        default => sub{1;}
);
has _cached_item => (
        is => 'rw',
        isa => 'Grim::XML::Media::Record::Item',
        default => sub{
                Grim::XML::Media::Record::Item->new();
        }
);
sub new_item{
        my $self = shift;
        $self->_cached_item->file([]);
        $self->_cached_item->devs([]);
        $self->_cached_item->services([]);
        $self->_cached_item->access("public");
        $self->_cached_item->context("Image");
        $self->_cached_item;
}
sub add_item {
        my($self,$item)=@_;
	my $item_id = $item->item_id || scalar(@{$self->items})+1;
	$item->item_id($item_id);
        push @{$self->items},clone($item);
}

no Moose;
1;

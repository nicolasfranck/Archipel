package Grim::XML::Media::Record::Item;
use Moose;
use Moose::Util::TypeConstraints;

has file => (
        is => 'rw',
        isa => 'ArrayRef[HashRef]',
        required => 0,
        default => sub{[]}
);
has devs => (
        is => 'rw',
        isa => 'ArrayRef[Str]',
        required => 0,
        default => sub{[]}
);
has services => (
        is => 'rw',
        isa => 'ArrayRef[Str]',
        required => 0,
        default => sub{[]}
);
has access => (
        is => 'rw',
        isa => enum([qw(public private)]),
        required => 0,
        default => sub{"public"}
);
has context => (
        is => 'rw',
        isa => enum([qw(Image Video)]),
        required => 0,
        default => sub{"Image"}
);
has action => (
        is => 'rw',
        isa => enum([qw(init add remove)]),
        required => 0,
        default => sub{"init"}
);
has title => (
	is => 'rw',
	isa => 'Str',
	required => 0
);
has item_id => (
	is => 'rw',
	isa => 'Int',
	required => 0
);

no Moose;
1;

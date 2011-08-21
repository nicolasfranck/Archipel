package PeepShow::googlemaps;
use Catmandu::App;
use parent qw(PeepShow::App::Common);

any([qw(get post)],'',sub{
        my $self = shift;
        $self->print_template($self->template('googlemaps'),$self->page_args);
});

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

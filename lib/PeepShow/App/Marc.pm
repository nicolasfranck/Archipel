package PeepShow::App::Marc;
use Catmandu::App;

sub marc_transformations {
        my $self = shift;
        $self->stash->{marc_transformations}||=$self->load_transformations;
}
sub load_transformations{
        my $self = shift;
        my $hash = {};
        my $t = Catmandu->conf->{package}->{Marc}->{Transformations};
        foreach my $key(keys %$t){
                my $class=$t->{$key};
                Plack::Util::load_class($class);
                $hash->{$key}=$class->new();
        }
        $hash || {};
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

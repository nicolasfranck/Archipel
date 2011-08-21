package PeepShow::App::Search;
use Catmandu::App;
use Text::Glob qw(glob_to_regex);

sub allowed_range {
        my $self = shift;
        Catmandu->stash->{allowed_range} ||= glob_to_regex(Catmandu->conf->{all}->{allowed_range});
}
sub is_local {
        my $self = shift;
        $self->source_ip =~ $self->allowed_range;
}

sub source_ip {
        my $self = shift;
        my $source_ip = $self->env->{HTTP_X_FORWARDED_FOR} ? $self->env->{HTTP_X_FORWARDED_FOR} : $self->env->{REMOTE_ADDR};
        my @ips = split(',',$source_ip);
        $source_ip = pop @ips;
        return $source_ip;
}
sub store_sess {
        my($self,$hash)=@_;
        $self->request->session->{$_}=$hash->{$_} foreach(keys %$hash);
}
sub store_param {
        my($self,$hash)=@_;
        $self->request->parameters->add($_ => $hash->{$_}) foreach(keys %$hash);
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

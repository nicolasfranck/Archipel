package PeepShow::help;
use Catmandu::App;
use parent qw(PeepShow::App::Common);

any([qw(get post)],'',sub{
	my $self = shift;
	my $args = {
		services => $self->services,
	};
	my $page_args = $self->page_args;
	$page_args->{args} = {%{$page_args->{args}},%$args};
	$self->print_template($self->template('help'),$page_args);
});
sub services {
	my $self = shift;
	my $services = {};
	foreach(keys %{Catmandu->conf->{context}}){
		foreach my $svc_id(keys %{Catmandu->conf->{context}->{$_}}){
			$services->{$svc_id}=1;
		}
	}
	$services->{$_} = 1 foreach(keys %{Catmandu->conf->{service_aggregate}});
	[keys %$services];
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

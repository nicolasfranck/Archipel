package Catmandu::Cmd::Command::idsvalid;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

with qw(Catmandu::Cmd::Opts::Grim::Store);

has _store => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                my $class = "Catmandu::Store::Simple";
                Plack::Util::load_class($class);
                $class->new(%{$self->store_arg});
        }
);
has _re => (
        is => 'rw',
        isa => 'Ref',
	default => sub{
		qr/^rug01:\d{9}$/;
	}
);
sub execute{
        my($self,$opts,$args)=@_;
	$self->_store->each(sub{
		my $record = shift;
		if($record->{_id} =~ $self->_re){
			print $record->{_id}."\n";
		}else{
			print STDERR $record->{_id}."\n";
		}		
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

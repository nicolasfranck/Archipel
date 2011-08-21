package Catmandu::Cmd::Command::load;
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

has id => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'r',
	documentation => "id [required]",
	required => 1
);
sub execute{
        my($self,$opts,$args)=@_;
	my $record = $self->_store->load($self->id);
	my $total_size_files = 0;
	my $total_size_devs = {};
	foreach my $item(@{$record->{media}}){
		foreach my $file(@{$item->{file}}){
			$total_size_files += $file->{size};
		}
		foreach my $svc_id(keys %{$item->{devs}}){
			$total_size_devs->{$svc_id} += $item->{devs}->{$svc_id}->{size};
		}
	}
	print "num files:".scalar(@{$record->{media}})."\n";
	print "total size files:$total_size_files\n";
	foreach my $svc_id(keys %$total_size_devs){
		print "total size $svc_id:".$total_size_devs->{$svc_id}."\n";
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

package Catmandu::Cmd::Command::files;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

has storetype => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 's',
    documentation => "Type of store [default:Simple]",
        default => sub{"Simple";}
);

has db_args => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]"
);
has id => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'r',
	documentation => "list only files of this id",
	required => 0
);
sub print_files{
	my($self,$record)=@_;
	foreach my $item(@{$record->{media}}){
		foreach my $file(@{$item->{file}}){
        		print $file->{path}."\n";
	       	}
	}
}
sub execute{
        my($self,$opts,$args)=@_;
	my $class = "Catmandu::Store::".$self->storetype;
	Plack::Util::load_class($class) or die();
	my $store = $class->new(%{$self->db_args});
	if(defined($self->id)){
		my $record = $store->load($self->id);
		$self->print_files($record) if defined($record);
	}else{
		$store->each(sub{
			$self->print_files(shift);
		});
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

package Catmandu::Cmd::Command::import2tmp;
our $VERSION = 0.01;
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;
extends qw(Catmandu::Cmd::Command);

with qw(
    Catmandu::Cmd::Opts::Fix
);


use Catmandu::Store::Simple;

has map => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'm',
	documentation => "Map file (default: \$HOME_PEEPSHOW/maps/aleph.map)",
);
has file => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	required => 1,
	cmd_aliases => 'i',
	documentation => "Path to the Marc-file.",
);
has interface => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'I',
	documentation => "Interface class to import (default: Aleph).",
	default => sub{'Aleph'}
);
has dbout => (
        traits => ['Getopt'],
	is => 'rw',
	isa => 'HashRef',
        cmd_aliases => 'o',
        documentation => "Database arguments to the temporary metadata database.",
	required => 1
);
has _dbout => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub {
		Catmandu::Store::Simple->new(%{shift->dbout});
	}
);
sub date2year {
        my($self,$date)=@_;
        $date = substr($date,7,4);
        my $year;
	if($date =~ /^(\d{4})$/){
                $year = $1;
        }
	elsif($date =~ /^(\d{3})\?$/){
                $year = $1*10;
        }
	elsif($date =~ /^(\d{2})\?\?$/){
                $year = $1*100;
        }
        else{
                $year = 0;
        }
        return $year;
}
sub localfix {
	my($self,$record)=@_;
	$record->{year} = [$self->date2year($record->{date}->[0])];
	delete $record->{date};
	return $record;
}
sub execute{
        my($self,$opts,$args)=@_;
	$self->map("../maps/aleph.map") if not defined($self->map);
	$self->fix("../fix/aleph.fix") if not defined($self->fix);
	my $class = "Catmandu::Importer::".$self->interface;
	Plack::Util::load_class($class);
	my $interface = $class->new(map=>$self->map,file=>$self->file);
	print "fixing imported data..\n";
	if($self->has_fix){
		$interface = $self->fixer->fix($interface);
	}
	print "saving fixed import data to new database\n";
	my $count = 0;
	$interface->each(sub{
		my $record = shift;
		print $record->{_id}."\n";
		$record = $self->localfix($record);
		$self->_dbout->save($record);
		$count++;
	});
	print "imported $count records\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;
__END__

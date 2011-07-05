package Catmandu::Cmd::Command::diff;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
use Array::Diff;
use List::MoreUtils qw(first_index);
use Catmandu::Store::Simple;

has dbin => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Parameters for the database [required]",
        required => 1
);
has file => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'f',
	documentation => "File containing the id's [required]",
	required => 1
);
has kind => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'k',
	documentation => "Kind of difference [default:id, others:files,devs]",
	default => sub{
		"id";	
	}
);
has _dbin => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		Catmandu::Store::Simple->new(%{shift->dbin});
	}
);
has _kinds => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub{
		['id','files','devs'];
	}
);
sub diff{
	my($self,$first,$second)=@_;
	my $diff = Array::Diff->diff([sort @$first],[sort @$second]);
	$diff->added,$diff->deleted;
}
sub list{
	my $self = shift;
	my $list = [];
	my $index = first_index {$_ eq $self->kind} @{$self->_kinds};
	$index = 0 if $index == -1;
        $self->_dbin->each(sub{
		my $record = shift;
		if($index == 0){
			push @$list,$record->{_id};
		}elsif($index == 1){
			foreach my $item(@{$record->{media}}){
				push @$list,$_->{path} foreach(@{$item->{file}});
			}
		}elsif($index == 2){
			foreach my $item(@{$record->{media}}){
				push @$list,$item->{devs}->{$_}->{path} foreach(keys %{$item->{devs}});
			}
		}
        });
	$list;
}
sub execute{
        my($self,$opts,$args)=@_;
	#ids
	my $file_list = [];
	open FILE,$self->file or die($!);
	while(<FILE>){
		chomp;
		push @$file_list,$_;
	}
	close FILE;
	#databank
	my $db_list = $self->list;
	my($added,$deleted) = $self->diff($file_list,$db_list);
	if(scalar(@$added)){
		print "In database, but not in list:\n";
		foreach(@$added){
			print "$_\n";
		}
	}
        if(scalar(@$deleted)){
                print "In list, but not in database:\n";
                foreach(@$deleted){
                        print "$_\n";
                }
        }
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

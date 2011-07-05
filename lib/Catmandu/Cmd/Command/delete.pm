package Catmandu::Cmd::Command::delete;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;

extends qw(Catmandu::Cmd::Command);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;

has dba => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'a',
    documentation => "Parameters for the meta database [required]",
    required => 1
);
has dbb => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'b',
    documentation => "Parameters for the media database [required]",
    required => 1
);
has index => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'HashRef',
	cmd_aliases => 'i',
	documentation => "Parameters for the index (has default)",
	required => 0,
	default => sub{
		{url => "http://localhost:8983/solr",id_field=>'id'};
	}
);
has reference => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'r',
    documentation => "id | file [required]",
    required => 1
);
has _dba => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		my $self = shift;
		Catmandu::Store::Simple->new(%{$self->dba});
	}
);
has _dbb => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
		my $self = shift;
                Catmandu::Store::Simple->new(%{$self->dbb});
        }
);
has _index => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
		my $self = shift;
                Catmandu::Index::Solr->new(%{$self->index});
        }
);
sub delete_files{
	my($self,$record)=@_;
	foreach my $item(@{$record->{media}}){
		foreach my $f(@{$item->{file}}){
			$self->delete($f->{path}) or return 0;
		}
		foreach my $s(keys %{$item->{devs}}){
			$self->delete($item->{devs}->{$s}->{path}) or return 0;
		}
	}	
	return 1;
}
sub delete{
	my($self,$path)=@_;
	if(defined($path)){
        	if(-f $path){
                	print "deleting $path\n";
                        unlink($path)or return 0;
                }else{
        	        print "$path does not exist, ignoring..\n";
                }
	}else{
        	print "path is not defined, ignoring..\n";
       	}
}

sub execute{
        my($self,$opts,$args)=@_;
	my $re = qr/rug01:\d{9}/;
	my @ids = ();
	if($self->reference =~ $re){
		push @ids,$self->reference;
	}elsif(-r $self->reference){
		open FILE,$self->reference or die($!);
		while(<FILE>){
			chomp;
			push @ids,$_ if $_ =~ $re;
		}
		close FILE;
	}else{
		die("reference must be id or file\n");
	}
	foreach my $id(@ids){
		my $ra = $self->_dba->load($id);
		my $rb = $self->_dbb->load($id);
		if(defined($ra) && defined($rb)){
			print "$id\n";
			print "deleting files\n";
			$self->delete_files($rb);
			print "deleting media-record\n";
			$self->_dbb->delete($id);
			print "deleting metadata-record\n";
			$self->_dba->delete($id);
			print "deleting index-document\n";
			$self->_index->delete($id);
		}
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;


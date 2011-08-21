package Catmandu::Cmd::Command::delete;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;

extends qw(Catmandu::Cmd::Command);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;

with qw(
	Catmandu::Cmd::Opts::Grim::Index::Solr
	Catmandu::Cmd::Opts::Grim::Store::Metadata
	Catmandu::Cmd::Opts::Grim::Store::Media
	Catmandu::Cmd::Opts::Grim::Store::Merge
);

has reference => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'r',
    documentation => "id | file [required]",
    required => 1
);
has _metadata => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		my $self = shift;
		Catmandu::Store::Simple->new(%{$self->metadata_arg});
	}
);
has _media => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
                Catmandu::Store::Simple->new(%{shift->media_arg});
        }
);
has _index => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
                Catmandu::Index::Solr->new(%{shift->index_arg});
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
		my $ra = $self->_metadata->load($id);
		my $rb = $self->_media->load($id);
		if(defined($ra) && defined($rb)){
			print "$id\n";
			print "deleting files\n";
			$self->delete_files($rb);
			print "deleting media-record\n";
			$self->_media->delete($id);
			print "deleting metadata-record\n";
			$self->_metadata->delete($id);
			print "deleting index-document\n";
			$self->_index->delete($id);
		}
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;


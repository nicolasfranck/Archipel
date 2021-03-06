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
	lazy => 1,
	default => sub{
		Catmandu::Store::Simple->new(%{shift->metadata_arg});
	}
);
has _media => (
        is => 'rw',
        isa => 'Ref',
	lazy => 1,
        default => sub{
                Catmandu::Store::Simple->new(%{shift->media_arg});
        }
);
has _index => (
        is => 'rw',
        isa => 'Ref',
	lazy => 1,
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
	my @ids = ();
	if(!-r $self->reference){
		push @ids,$self->reference;
	}else{
		open FILE,$self->reference or die($!);
		while(<FILE>){
			chomp;
			push @ids,$_;
		}
		close FILE;
	}
	my $i = 0;
	foreach my $id(@ids){
		my $ra = $self->_metadata->load($id);
		my $rb = $self->_media->load($id);
		if(defined($ra) && defined($rb)){
			print "$id\n";
			#eerst deleten uit de index, zodat de zoekmachine ze niet meer kan vinden en fouten maken..
			print "deleting index-document\n";
			$self->_index->delete($id);
			$i++;
			if($i>1000){
				$i = 0;
				print "committing work\n";
				$self->_index->commit;
			}
			print "deleting files\n";
			$self->delete_files($rb);
			print "deleting media-record\n";
			$self->_media->delete($id);
			print "deleting metadata-record\n";
			$self->_metadata->delete($id);
		}
	}
	print "committing work\n";
	$self->_index->commit;
	print "optimizing work\n";
	$self->_index->optimize;
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;


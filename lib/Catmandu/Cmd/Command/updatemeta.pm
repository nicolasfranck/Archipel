package Catmandu::Cmd::Command::updatemeta;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);
with qw(
        Catmandu::Cmd::Opts::Grim::Index::Solr
        Catmandu::Cmd::Opts::Grim::Index::Make
	Catmandu::Cmd::Opts::Grim::Store::Metadata
	Catmandu::Cmd::Opts::Grim::Store::Media
        Catmandu::Cmd::Opts::Grim::Store::Merge
);

use utf8;
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use Try::Tiny;

has temp_arg => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Temporary meta database [required]",
    required => 1
);

has _temp => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->temp_arg}) or die("could not open temporary meta database");
        }
);
has _metadata => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->metadata_arg}) or die("could not open metadata database");
        }
);
has _media => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->media_arg}) or die("could not open media database");
        }
);

has _index => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Index::Solr->new(%{$self->index_arg});
        }
);
sub execute{
        my($self,$opts,$args)=@_;
	my $i = 0;
	my $count = 0;
	$self->_temp->each(sub{
		$i++;
		my $newmetarecord = shift;
		#komt het voor in de merge?
		my $oldmetarecord = $self->_metadata->load($newmetarecord->{_id});
		my $mediarecord = $self->_media->load($newmetarecord->{_id});
		if(defined($oldmetarecord) && defined($mediarecord)){
			print $newmetarecord->{_id}."\n";
			$self->_metadata->save($newmetarecord);
			$self->_index->save($self->make_index_merge($newmetarecord,$mediarecord));
			$count++;
			if($count>1000){
				$self->_index->commit;
				$count = 0;
			}
		}
	});
	$self->_index->commit;
	$self->_index->optimize;
	print "$i records updated\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

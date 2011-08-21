package Catmandu::Cmd::Command::indexmerge;
our $VERSION = 0.01;# VERSION
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
use Catmandu::Index::Solr;
use Catmandu::Store::Simple;
use Try::Tiny;
use Array::Diff;

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
sub diff{
        my($self,$first,$second)=@_;
        my $diff = Array::Diff->diff([sort @$first],[sort @$second]);
        $diff->added,$diff->deleted;
}
sub equal{
	my $self = shift;
	my $stha = $self->_metadata->_dbh->prepare('select id from objects') or croak($self->_metadata->_dbh->{errstr});
	$stha->execute;
	my $sthb = $self->_media->_dbh->prepare('select id from objects') or croak ($self->_media->_dbh);
	$sthb->execute;
	my $a = $stha->fetchall_arrayref;
	my $b = $sthb->fetchall_arrayref;
	$a = [map {$_->[0]} @$a];
	$b = [map {$_->[0]} @$b];
	my($added,$deleted)=$self->diff($a,$b);
	return scalar(@$added) == 0 && scalar(@$deleted) == 0;
}

sub execute{
        my($self,$opts,$args)=@_;
	if(not $self->skip){
		die "both databases are not equal\n" if not $self->equal;
	}
	#verzamel tweelingen
	try{
		$self->_metadata->each(sub{
			my $a = shift;
			my $b = $self->_media->load($a->{_id});
			if(defined($b) && defined($b->{media}) && scalar(@{$b->{media}} > 0)){
				print $a->{_id}."\n";
				$self->_index->save($self->make_index_merge($a,$b));
			}else{
				return;
			}
		});
	}catch{
		print $_;
	};
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

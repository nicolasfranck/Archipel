package Catmandu::Cmd::Command::publish;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Clone qw(clone);
extends qw(Catmandu::Cmd::Command);


with qw(
	Catmandu::Cmd::Opts::Grim::Index::Solr
);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;

has media_arg => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'HashRef',
	cmd_aliases => 'd',
	documentation => "Parameters for the media database [required]",
	required => 0,
	default => sub{
		{path => $ENV{HOME}."/data/media.db"};
	}
);
has _media => (
	is => 'ro',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		Catmandu::Store::Simple->new(%{shift->media_arg});
	}
);
has _index => (
        is => 'ro',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                Catmandu::Index::Solr->new(%{shift->index_arg});
        }
);
# public="thumbnail small" private="zoomer"
has level => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'HashRef',
        cmd_aliases => 'l',
        documentation => "Access level to gain [required]",
        required => 1
);
has query => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'q',
        documentation => "Query to match against [required]",
        required => 1
);
has _services => (
	is => 'ro',
	isa => 'HashRef',
	default => sub{
		{'thumbnail'=>1,'small'=>1,'medium'=>0,'large'=>0,'zoomer'=>0,'videostreaming'=>0,'videolink'=>0};
	}
);
sub level_valid {
	my $self = shift;
	my $level;
	return 0,"invalid number access levels" if scalar(keys %{$self->level}) > 2;
	foreach my $access(keys %{$self->level}){
		return 0,"invalid access level $access" if $access ne "public" && $access ne "private";
		$level->{$access}={};
		my @services = split(' ',$self->level->{$access});
		foreach my $service(@services){
			return 0,"invalid service $service" if not defined($self->_services->{$service});
			$level->{$access}->{$service}=1;
		}
	}	
	#dubbels? vb public=thumbnail private=thumbnail
	foreach my $s(keys %{$level->{public}}){
		return 0,"duplicate service $s" if defined($level->{private}->{$s});
	}	
	$self->level($level);
	return 1,undef;
}
sub publish_record {
	my($self,$record)=@_;
	foreach my $access(%{$self->level}){
		foreach my $svc_id(keys %{$self->level->{$access}}){
			$record->{access}->{services}->{$svc_id} = ($access eq "public")? 1:0;
		}
	}
	return $record;
}
sub execute{
        my($self,$opts,$args)=@_;
	#check level
	my($success,$errmsg)=$self->level_valid;
	die("$errmsg\n") if not $success;
	#haal id's op
	my $hits = [];
	my $total_hits = 1;
	my $start = 0;
	#limit -> liefst niet te laag, om CPU-gebruik laag te houden
	my $limit = 2000;
	#updating database
	my $i = 0;
	while($start < $total_hits){
		($hits,$total_hits)=$self->_index->search($self->query,start=>$start,limit=>$limit,sort=>"id asc");
		#itereer over hits
		foreach my $hit(@$hits){
			print $hit->{id}."\n";
			my $record = $self->_media->load($hit->{id});			
			$record = $self->publish_record($record);
			$self->_media->save($record);
		}
		$start += $limit;
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

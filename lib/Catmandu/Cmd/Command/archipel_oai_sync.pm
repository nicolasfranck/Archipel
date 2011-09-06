package Catmandu::Cmd::Command::archipel_oai_sync;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
with qw(
	Catmandu::Cmd::Opts::Grim::Store::Media
	Catmandu::Cmd::Opts::Grim::Store::Metadata
	Catmandu::Cmd::Opts::Grim::Index::Solr
	Catmandu::Cmd::Opts::Grim::Index::Make
	Catmandu::Cmd::Opts::Grim::Harvester
);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use File::Temp;
use Image::ExifTool;
use Clone qw(clone);

our @OAI_DC_ELEMENTS = qw(
    title 
    creator 
    subject 
    description 
    publisher 
    contributor 
    date
    type
    format
    identifier
    source
    language
    relation
    coverage
    rights
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
has _exif => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		Image::ExifTool->new;
	}
);
has _ua => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
                LWP::UserAgent->new(cookie_jar=>{});
        }
);
sub make_metadata_record {
	my($self,$oai_record)=@_;
	my $new_metadata_record = {};
	$new_metadata_record->{$_} = $oai_record->metadata->{$_} foreach(@OAI_DC_ELEMENTS);
	$new_metadata_record->{_id} = $oai_record->header->identifier;
	return $new_metadata_record;
}
sub make_media_record {
	my($self,$oai_record)=@_;

	my $context = ucfirst(lc($oai_record->metadata->{type}));
	my $services = {"thumbnail"=>1,"videostreaming"=>1};
	my $files = [];
	my $item = {item_id=>1,context=>"Video",services=>[keys %$services]};

	my $media_record= {
		_id => $oai_record->header->identifier,
		access => {
			services => clone($services)
		},
		poster_item_id => 1,
		media => []
	};
	my $still_url;
	my $media_url;
	#afleiden van still en media
	foreach my $relation(@{$oai_record->metadata->{relation}}){
		if($relation =~ /\/still/){
			$still_url = $relation;
		}elsif($relation =~ /\/media/){
			$media_url = $relation;
		}
	}

	#file downloaden en inspecteren
	if(!defined($media_url)){
		print "\tno url found\n";
		return;
	}
	my $response = $self->_ua->get($media_url);
        return undef,$response->content if not $response->is_success;
        my $tempfile = tmpnam();
        open FILE,">$tempfile" or return undef,$!;
        print FILE $response->content;
        close FILE;
	my $media_info = $self->_exif->ImageInfo($tempfile);
	$files->[0]->{url} = $media_url;
	$files->[0]->{streaming_provider} = "http";
	$files->[0]->{width} = $media_info->{ImageWidth};
	$files->[0]->{height} = $media_info->{ImageHeight};
	$files->[0]->{size} = -s $tempfile;
	$files->[0]->{content_type} = $media_info->{MIMEType};
	unlink($tempfile) if -w $tempfile;
	$item->{file} = $files;

	#haal still op en inspecteer (want bestaat geen metadata over)
	my $thumbnail = {};
        $response = $self->_ua->get($still_url);
        return undef,$response->content if not $response->is_success;
        $tempfile = tmpnam();
        open FILE,">$tempfile" or return undef,$!;
        print FILE $response->content;
        close FILE;
        my $still_info = $self->_exif->ImageInfo($tempfile);

	$thumbnail->{url} = $still_url;	
	$thumbnail->{width} = $still_info->{ImageWidth};
	$thumbnail->{height} = $still_info->{ImageHeight};
	$thumbnail->{size} = -s $tempfile;
        $thumbnail->{content_type} = $still_info->{MIMEType};
	
	$item->{devs}->{thumbnail} = $thumbnail;
	unlink($tempfile) if -w $tempfile;



	push @{$media_record->{media}},$item;

	return $media_record,undef;
}
sub confirm {
	my($self,$complete_list_size)=@_;
	my $answer = "";
	do{
		print "complete list size:$complete_list_size. Do you want to continue? [y|n]";
		$answer = lc(<STDIN>);
		chomp $answer;
	}while($answer ne "y" && $answer ne "n");
	return $answer eq "y";
}
sub execute{
        my($self,$opts,$args)=@_;
	#harvest
	my $iterator = $self->_harvester->listAllRecords(metadataPrefix=>'oai_dc');	
	if($iterator->errorCode){
		printf STDERR "%15s : %s\n","errorCode",$iterator->errorCode;
		printf STDERR "%15s : %s\n","errorCode",$iterator->errorString;
		exit(1);
	}
	$self->cancel if(!$self->confirm($iterator->resumptionToken->completeListSize));
	while(my $record = $iterator->next){
		print $record->header->identifier."\n";
		next if $self->_media->load($record->header->identifier);
		my $new_metadata_record = $self->make_metadata_record($record);
		my($new_media_record,$errmsg) = $self->make_media_record($record);
		if(defined($errmsg)){
			print "\terror:$errmsg\n";
			print "\tskipping this record\n";
		}
		$self->_metadata->save($new_metadata_record);
		$self->_media->save($new_media_record);
		$self->_index->save($self->make_index_merge($new_metadata_record,$new_media_record));
	}
}
sub cancel {
	my $self = shift;
	print "operation cancelled\n";
	exit(0);
}
sub fatal {
	my($self,$errmsg)=@_;
	print STDERR $errmsg;
	exit(1);
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

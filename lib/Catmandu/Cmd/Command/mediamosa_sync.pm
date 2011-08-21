package Catmandu::Cmd::Command::mediamosa_sync;
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
	Catmandu::Cmd::Opts::Grim::MediaMosa
);
use Net::OAI::Harvester;
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use File::Temp;
use Image::ExifTool;
use Clone qw(clone);
use Data::Dumper;


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
sub make_metadata_record {
	my($self,$oai_record)=@_;
	my $new_metadata_record = {};
	foreach my $fobject(@{$self->_yaml_mediamosa->{fields}}){
		next if $fobject->{mappings}->{oai_dc}->{present} eq "false";
		if(defined($fobject->{mappings}->{oai_dc}->{identifier}) && $fobject->{mappings}->{oai_dc}->{identifier} eq "true"){
			$new_metadata_record->{_id} = $oai_record->header->identifier;
			next;
		}
		my $aleph_metadata_key = $fobject->{key};
		my $oai_metadata_key = $fobject->{mappings}->{oai_dc}->{key};
		my @data = $oai_record->metadata->$oai_metadata_key() || ();
		next if scalar(@data)==0;
		$new_metadata_record->{$aleph_metadata_key} = \@data;
	}
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
			print "\tstill_url: $still_url\n";
		}elsif($relation =~ /\/media/){
			$media_url = $relation;
			print "\tmedia_url: $media_url\n";
		}
	}

	#file downloaden en inspecteren
	print "\tdownloading media_url..\n";
	my $response = $self->_ua->get($media_url);
        return undef,$response->content if not $response->is_success;
        my $tempfile = tmpnam();
        open FILE,">$tempfile" or return undef,$!;
        print FILE $response->content;
        close FILE;
        print "\tinspecting media_url..\n";
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
	print "\tdownloading still_url..\n";
        $response = $self->_ua->get($still_url);
        return undef,$response->content if not $response->is_success;
        $tempfile = tmpnam();
        open FILE,">$tempfile" or return undef,$!;
        print FILE $response->content;
        close FILE;
        print "\tinspecting still_url..\n";
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
	my $records = $self->_harvester->listAllRecords(metadataPrefix=>'oai_dc');
	$self->cancel if(!$self->confirm($records->resumptionToken->completeListSize));
	while(my $record = $records->next){
		print $record->header->identifier."\n";
		my $new_metadata_record = $self->make_metadata_record($record);
		my($new_media_record,$errmsg) = $self->make_media_record($record);
		if(defined($errmsg)){
			print "\terror:$errmsg\n";
			print "\tskipping this record\n";
		}
		$self->_metadata->save($new_metadata_record);
		$self->_media->save($new_media_record);
		print "\tsaving to index\n";
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

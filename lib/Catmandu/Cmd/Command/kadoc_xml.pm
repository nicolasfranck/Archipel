package Catmandu::Cmd::Command::kadoc_xml;
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
);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use File::Temp;
use Image::ExifTool;
use Clone qw(clone);
use XML::Simple;
use Data::Dumper;

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
has xml_file => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        required => 1,
        cmd_aliases => 'x',
        documentation => "Path to the xml-file.",
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
has _xml_parser => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub {
		XML::Simple->new;
	}
);
sub make_metadata_record {
	my($self,$oai_record)=@_;
	my $new_metadata_record = {};
	$new_metadata_record->{$_} = $oai_record->{$_} foreach(@OAI_DC_ELEMENTS);
	$new_metadata_record->{_id} = $oai_record->{identifier}->[0];
	return $new_metadata_record;
}
sub make_media_record {
	my($self,$oai_record)=@_;

	my $services = {"thumbnail"=>1};
	my $item = {item_id=>1,context=>"Image",services=>[keys %$services],files=>[]};

	my $media_record= {
		_id => $oai_record->{identifier}->[0],
		access => {
			services => clone($services)
		},
		poster_item_id => 1,
		media => []
	};
	my $still_url = $oai_record->{relation}->[0];

	#haal still op en inspecteer (want bestaat geen metadata over)
	my $thumbnail = {};
	print "downloading $still_url\n";
        my $response = $self->_ua->get($still_url);
        return undef,$response->content if not $response->is_success;
        my $tempfile = tmpnam();
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
sub execute{
        my($self,$opts,$args)=@_;
	#parse xml-bestand
	my $hash = $self->_xml_parser->XMLin($self->xml_file,NoAttr=>1,ForceArray=>1);
	foreach my $record(@{$hash->{'oai_dc:dc'}}){
		#zet om naar oai-record
		my $new_record = {};
		foreach my $key(keys %$record){
			my $new_key = $key;
			$new_key =~ s/^dc://;
			if(ref $record->{$key} eq "ARRAY"){
				$new_record->{$new_key} = [];
				push @{$new_record->{$new_key}},$_ foreach(@{$record->{$key}});
			}
			else {
				$new_record->{$new_key} = [$record->{$key}];
			}
		}
		$new_record->{_id} = $new_record->{identifier}->[0];
		#check of het al bestaat in de databank
		next if $self->_media->load($new_record->{_id});
		#print id
		print $new_record->{_id}."\n";
		#..en importeer
		my $new_metadata_record = $self->make_metadata_record($new_record);
                my($new_media_record,$errmsg) = $self->make_media_record($new_record);
                if(defined($errmsg)){
                        print "\terror:$errmsg\n";
                        print "\tskipping this record\n";
                }
		print Dumper($new_metadata_record);
		
		print Dumper($self->make_index_merge($new_metadata_record,$new_media_record));
               # $self->_metadata->save($new_metadata_record);
               # $self->_media->save($new_media_record);
               # $self->_index->save($self->make_index_merge($new_metadata_record,$new_media_record));
	}
}
sub fatal {
	my($self,$errmsg)=@_;
	print STDERR $errmsg;
	exit(1);
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

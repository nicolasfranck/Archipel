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
	Catmandu::Cmd::Opts::Grim::Harvester
);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use File::Temp;
use Image::ExifTool;
use Clone qw(clone);
use Image::Magick::Thumbnail::Simple;
use Data::UUID;
use parent qw(Catmandu::Cmd::Stats);

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
my @sizes = (
        { key => "large",min => 601,max=>10000 },
        { key => "medium",min => 301,max => 600 },
        { key => "small",min => 151,max=>300 },
        { key => "thumbnail",min => 1,max => 150 }
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
has _thumber => (
	is => 'rw',
	isa => 'Ref',
	default => sub { Image::Magick::Thumbnail::Simple->new; }
);
sub choose_path{
        my $self = shift;
        my $addpath;
        my($second,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime time;
        $year += 1900;
        $addpath = "$year/$mon/$mday/$hour/$min/$second";
        return $addpath;
}
sub make_metadata_record {
	my($self,$oai_record)=@_;
	my $new_metadata_record = {};
	$new_metadata_record->{$_} = $oai_record->metadata->{$_} foreach(@OAI_DC_ELEMENTS);
	$new_metadata_record->{_id} = $oai_record->header->identifier;
	return $new_metadata_record;
}
sub make_media_record {
	my($self,$oai_record)=@_;

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

	my $services = {"thumbnail"=>1};
	$services->{video} = 1 if $media_url;
	my $item = {item_id=>1,context=>"Video",services=>[keys %$services]};

	my $media_record= {
		_id => $oai_record->header->identifier,
		access => {
			services => clone($services)
		},
		poster_item_id => 1,
		media => []
	};

	my $files = [];
	#file downloaden en inspecteren
	if($media_url){
		my $response = $self->_ua->get($media_url);
		return undef,$response->content if not $response->is_success;
		my $tempfile = tmpnam();
		open FILE,">$tempfile" or return undef,$!;
		print FILE $response->content;
		close FILE;
		my $media_info = $self->_exif->ImageInfo($tempfile);
		$files->[0]->{url} = $media_url;
		$files->[0]->{width} = $media_info->{ImageWidth};
		$files->[0]->{height} = $media_info->{ImageHeight};
		$files->[0]->{size} = -s $tempfile;
		$files->[0]->{content_type} = $media_info->{MIMEType};
		unlink($tempfile) if -w $tempfile;
	}
	$item->{file} = $files;

	#haal still op en inspecteer (want bestaat geen metadata over)
	if($still_url){
		my $thumbnail = {};
		my $response = $self->_ua->get($still_url);
		return undef,$response->content if not $response->is_success;
		my $tempfile = tmpnam();
		open FILE,">$tempfile" or return undef,$!;
		print FILE $response->content;
		close FILE;
		my $still_info = $self->_exif->ImageInfo($tempfile);

		#welke afgeleiden kun je hieruit halen? (aanmaken of bewaren..)
		my $devs = {};
		my $maxlat = $still_info->{ImageWidth} > $still_info->{ImageHeight} ? $still_info->{ImageWidth} : $still_info->{ImageHeight};
		foreach my $size(@sizes){
			my $dev = {};
			if($maxlat >= $size->{min} && $maxlat <= $size->{max}){
				print "\tkeeping this for $size->{key}\n";
				$dev->{url} = $still_url;
				$dev->{width} = $still_info->{ImageWidth};
				$dev->{height} = $still_info->{ImageHeight};
				$dev->{size} = -s $tempfile;
				$dev->{content_type} = $still_info->{MIMEType};
			}elsif($maxlat > $size->{max}){
				print "\tmaking $size->{key}\n";
				my $added_path = $self->choose_path;
				my $basename = Data::UUID->new->create_str.".jpeg";
				my $output = "/data/thumbies/$added_path/$basename";
				my $success = $self->_thumber->thumbnail(
					size => $size->{max},
					input => $tempfile,
					output => $output
				);	
				if(!$success){
					die($self->_thumber->error."\n");
				}		
				my $dev_info = $self->_exif->ImageInfo($output);			
				$dev = {
					%{$self->stat_properties($output)},
					content_type => $dev_info->{MIMEType},
					width => $dev_info->{ImageWidth},
					height => $dev_info->{ImageHeight},
					url => "http://localhost/thumbies/$added_path/$basename"
				};
			}
			$item->{devs}->{$size->{key}} = $dev;
		}
		unlink($tempfile) if -w $tempfile;
	}

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
	my $found = 0;
	my $imported = 0;
	my $num_errs = 0;
	while(my $record = $iterator->next){
		print $record->header->identifier;
		$found++;
                if($record->header->status eq "deleted"){
                        print " marked as deleted, skipping\n";
                        next;
                }
		if($self->_media->load($record->header->identifier)){
			print " already in media database, skipping\n";
			next;
		}
		print "\n";
		my $new_metadata_record = $self->make_metadata_record($record);
		my($new_media_record,$errmsg) = $self->make_media_record($record);
		if(defined($errmsg)){
			$num_errs++;
			print "\terror:$errmsg\n";
			print "\tskipping this record\n";
		}
		$self->_metadata->save($new_metadata_record);
		$self->_media->save($new_media_record);
                $imported++;
	}
	print "$found records found, $imported records imported, $num_errs errors\n";
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

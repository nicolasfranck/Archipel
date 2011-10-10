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
use parent qw(Catmandu::Cmd::Stats);
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use File::Temp;
use File::Path qw(mkpath);
use Image::ExifTool;
use Clone qw(clone);
use Image::Magick::Thumbnail::Simple;
use Data::UUID;
use List::Util qw(min max);

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
has thumbdir => (
	traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 't',
        documentation => "thumbdir",
        required => 0
);
sub stat_properties {
        my($self,$filename)=@_;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)=stat($filename);
        open FILE,"<$filename" or die($!);
        my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
        close FILE;
        return {
                size => $size,
                date_created => $ctime,
                date_accessed=>$atime,
                date_modified=>$mtime,
                md5_checksum => $md5,
                path => $filename
        };
}
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

	my $media_record= {
                _id => $oai_record->header->identifier,
                access => {
                        services => {thumbnail=>1,small=>1,medium=>1,large=>1,videostreaming=>1,audiostreaming=>1}
                },
                poster_item_id => 1,
                media => []
        };
	my $item = {item_id=>1};
	my $files = [];
	my $context;
	my $services = {};
	my $devs = {};

	#afleiden van video/audio en afgeleide
	my($stillfound,$avfound);
	foreach my $relation(@{$oai_record->metadata->{relation}}){
		last if $avfound && $stillfound;
		print "\t$relation\n";
		my $response = $self->_ua->get($relation);
                if(!$response->is_success){
			warn "\tno success downloading $relation\n";
			next;
		}
                my $tempfile = tmpnam();
                open FILE,">$tempfile" or return undef,$!;
                print FILE $response->content;
                close FILE;
                my $info = $self->_exif->ImageInfo($tempfile);
		if($info->{MIMEType} =~ /^video/o && !$avfound){
			print "\tmimetype:$info->{MIMEType}\n";
			$files->[0]->{url} = $relation;
	                $files->[0]->{width} = $info->{ImageWidth};
        	        $files->[0]->{height} = $info->{ImageHeight};
                	$files->[0]->{size} = -s $tempfile;
	                $files->[0]->{content_type} = $info->{MIMEType};
			$context = "Video";
			$services->{videostreaming} = 1;
			$avfound = 1;
		}elsif($info->{MIMEType} =~ /^audio/o && !$avfound){
			print "\tmimetype:$info->{MIMEType}\n";
			$files->[0]->{url} = $relation;
                	$files->[0]->{size} = -s $tempfile;
	                $files->[0]->{content_type} = $info->{MIMEType};
			$context = "Audio";
			$services->{audiostreaming} = 1;
			$avfound = 1;
		}elsif($info->{MIMEType} =~ /^image/o && !$stillfound){
			print "\tmimetype:$info->{MIMEType}\n";
			#welke afgeleiden kun je hieruit halen? (aanmaken of bewaren..)
        	        my $maxlat = max($info->{ImageWidth},$info->{ImageHeight});
			foreach my $size(@sizes){
				my $dev = {};
				if($maxlat >= $size->{min} && $maxlat <= $size->{max}){
					print "\tkeeping this for $size->{key}\n";
					$dev->{url} = $relation;
					$dev->{width} = $info->{ImageWidth};
					$dev->{height} = $info->{ImageHeight};
					$dev->{size} = -s $tempfile;
					$dev->{content_type} = $info->{MIMEType};
				}elsif($maxlat > $size->{max}){
					print "\tmaking $size->{key}\n";
					my $added_path = $self->choose_path;
					my $basename = Data::UUID->new->create_str."_".$size->{key}.".jpeg";
					my $thumbdir = $self->thumbdir;
					my $output = "$thumbdir/$added_path/$basename";
					mkpath("$thumbdir/$added_path");
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
					};
				}
				if(scalar(keys %$dev) > 0){
                 	        	$devs->{$size->{key}} = $dev;
                        	        $services->{$size->{key}} = 1;
	                        }
        	        }
			$stillfound = 1;
		}else{
			warn "\t$info->{MIMEType} not supported\n";
			next;
		}
		unlink($tempfile) if -w $tempfile;
	}
	$item->{context} = $avfound ? $context:"Image";
	$item->{file} = $files;
	$item->{devs} = $devs;
	$item->{services} = [keys %$services];
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
	if(!-d $self->thumbdir){
		die($self->thumbdir." does not exist!\n");
	}
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

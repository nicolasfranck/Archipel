package Catmandu::Cmd::Command::unbag2tmp_jp2k;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#intern gebruik
use Archive::BagIt;
use Data::UUID;
use IO::CaptureOutput qw(capture_exec);
use Image::Magick;
use Image::Magick::Thumbnail::Simple;
use File::Basename;
use File::Path qw(mkpath rmtree);
use File::Copy;
use File::Temp qw(:POSIX);;
use Try::Tiny;
use Benchmark;
use Image::ExifTool;
use File::Temp qw(:POSIX);
use List::Util qw(min max sum);
use Catmandu::Store::Simple;
use Benchmark;
use IO::Tee;
use IO::File;
use Clone qw(clone);

has dbout => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'o',
    documentation => "Parameters for the temporary output database [required]",
	required => 1
);

has dir => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'i',
	documentation => "Directory to parse [required]",
	required => 1
);
has datadir => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'd',
    documentation => "Temporary directory to store the originals [required]",
    required => 1,
    trigger => sub{
	my $self = shift;
	die("datadir already exists! Please specify a nonexistant temporary directory!") if -d $self->datadir;
    }
);
has data_prefix_url => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'dp',
    documentation => "prefix url for the pyramid tiff (default:location on disk)"
);
has thumbdir => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 't',
    documentation => "Temporary directory to store the thumbs [required]",
    required => 1,
    trigger => sub{
        my $self = shift;
        die("thumbdir already exists! Please specify a nonexistant temporary directory!") if -d $self->thumbdir;
    }

);
has thumb_prefix_url => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'tp',
    documentation => "prefix url for the thumbnail (default:location on disk)"
);
has dbcheck => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'HashRef',
	cmd_aliases => 'cd',
	documentation => "if supplied, records that already exist in this database are skipped\n",
	required => 0
);
has tempdir => (
	traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'tempdir',
        documentation => "Used instead of /tmp to store temporary files\n",
        required => 0
);

has _bagit => (   
    is => 'rw',
    isa => 'Ref',  	
	default => sub{
		Archive::BagIt->new();
	}
);
has _dbout => (
	is => 'rw',
	isa => 'Ref',
	lazy => 1,
	default => sub {
		my $self = shift;
		die("database already exists! Please specify a nonexistant path!") if -f $self->dbout->{path};
		my $store = Catmandu::Store::Simple->new(%{$self->dbout});
	}
);
has _dbcheck => (
        is => 'rw',
        isa => 'Ref|Undef',
        lazy => 1,
        default => sub {
                my $self = shift;
		if(defined($self->dbcheck)){
	                return Catmandu::Store::Simple->new(%{$self->dbcheck});
		}else{
			undef;
		}
        }
);
has _dirs => (
	is => 'rw',
	isa => 'Ref',
	default => sub{[]}
);
has _thumber => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		Image::Magick::Thumbnail::Simple->new();
	}
);
has _magick => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		Image::Magick->new();
	}
);
has _exif => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		Image::ExifTool->new();
	}
);

has tee => (
	is => 'rw',
	isa => 'IO::Tee',
	lazy => 1,
	default => sub{
		my $self = shift;
		open STDERR,">/tmp/unbag2tmp-".time.".err";
		IO::Tee->new(
			\*STDOUT,IO::File->new(">/tmp/unbag2tmp-".time.".log")
		);
	}
);
sub check_orientation{
	my($self,$path)=@_;
	@{$self->_magick} = ();
	my $changed = 0;
	my $tmp_path = undef;
	my $info = $self->_exif->ImageInfo($path);
	if($info->{Orientation} ne "Horizontal (normal)"){
		if($self->tempdir){
			$tmp_path = $self->tempdir."/".Data::UUID->new->create_str.'.tif';
		}else{
			$tmp_path = tmpnam().".tif";
		}
		$self->_magick->Read($path);
		$self->_magick->AutoOrient();
		$self->_magick->Write($tmp_path);
		$changed = 1;
	}
	@{$self->_magick} = ();
	return $changed,$tmp_path;
}
sub create_jp2k{
	my($self,$input,$output)=@_;
	my $info = $self->_exif->ImageInfo($input);
	my $width = $info->{ImageWidth};
	my $height = $info->{ImageHeight};
	my $max = max($width,$height);
	my $temp;
	if($max > 4000){
		$temp = $self->tempdir."/".Data::UUID->new->create_str.'.tif';
		my $success = $self->create_thumb($input,$temp,4000);
		if(not $success){
			$self->tee->print(" error:error while storing pyramid in temporary file $temp","\n");
			unlink($temp) if -f $temp;
			return 0;
		}
		$input = $temp;
	}
	my $rate = sum(split(' ',$info->{BitsPerSample}));
	if($rate > 32){
		$rate = "24,32";
	}
	my $command = "kdu_compress -i $input Stiles='{256,256}' Clevels=8 Clayers=8 -rate $rate Creversible=yes Corder=RPCL -no_weights -o $output";
	$self->tee->print("$command\n");
	my($stdout, $stderr, $success, $exit_code) = capture_exec($command);
	if(not $success){
		$self->tee->print(" error:error while trying to create jpeg2000, aborting","\n");
		$self->tee->print("error:$stderr\n");
		unlink($output) if -f $output;
	}
	unlink($temp) if defined($temp) && -f $temp;
	return $success;
}
sub create_thumb{
	my($self,$input,$output,$size)=@_;
	$self->_thumber->thumbnail(
		input => $input,
		output => $output,
		size => $size
	);
}
sub choose_path{
	my $self = shift;
	my $addpath;
	my($second,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime time;
        $year += 1900;
        $addpath = "$year/$mon/$mday/$hour/$min/$second";
	return $addpath;
}
sub is_image{
	my($self,$file)=@_;
	return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;	
	my $info = $self->_exif->ImageInfo($file);
        return not defined($info->{Error});
}
sub is_jp2k{
	my($self,$file)=@_;
	return 0 if not defined($file);
	return 0 if not -f $file;
	return 0 if -s $file == 0;
	my $info = $self->_exif->ImageInfo($file);
	return 0 if defined($info->{Error});
	return 0 if $info->{FileType} ne "JP2";
	return 0 if $info->{MIMEType} ne "image/jp2";
	return 1;
}
sub is_ma{
	my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->_exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if uc($info->{FileType}) ne "TIFF";
        return 0 if $info->{MIMEType} ne "image/tiff";
	#return 0 if lc($info->{Compression}) ne "uncompressed";
	return 1;
}
sub is_jpeg{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->_exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "JPEG";
        return 0 if $info->{MIMEType} ne "image/jpeg";
        return 1;
}
sub record_exists{
	my($self,$id)=@_;
	if(defined($self->_dbcheck)){
		return defined($self->_dbcheck->load($id));
	}
	return 0;
}
sub id_valid{
	my($self,$id)=@_;
	$id =~ /^rug01:\d{9}$/;
}
sub process_bag{
	my($self,$dir) = @_;
	$self->tee->print("VALIDATING BAG..");
	#valideren van de bag
	$self->_bagit->read($dir);
	if(not $self->_bagit->valid){
    		$self->tee->print("[not complete, skipping bag]\n");
    		return 0;
    	}
	$self->tee->print(" [OK]\n");
	#afleiden van metadata
	$self->tee->print("LOOKING FOR DC-IDENTIFIER..");
	#baginfo 
	my $baginfo = {};
	foreach(@{$self->_bagit->_info}){
		if(defined($baginfo->{$_->[0]})){
			push @{$baginfo->{$_->[0]}},$_->[1];
		}else{
			$baginfo->{$_->[0]}=[$_->[1]];
		}
	}
	#_id <- DC-Identifier
	my $_id = $baginfo->{'DC-Identifier'}->[0];
	if(not defined($_id)){
		$self->tee->print("[not found, skipping bag]\n");
		return 0;
	}elsif(not $self->id_valid($_id)){
		$self->tee->print("[id $_id not valid, skipping bag]\n");
                return 0;
	}
	if($self->record_exists($_id)){
		$self->tee->print("[record exists in ".$self->_dbcheck->path.", skipping bag]\n");
		return 0;
	}
	$self->tee->print("[OK]\n");
	$self->tee->print("DC-Identifier:$_id\n\n");
	#vertrek van de master-files: is er een ac die ermee overeenstemt?
	my @payloads = grep {$_->name =~ /_MA\.tif$/i} $self->_bagit->list_files;
	#sorteer..
	@payloads = map{
    		$_->[1];
    	}sort {
		$a->[0] <=> $b->[0]
	} map {
        	$_->name =~ /_(\d+)_MA\.tif$/i;
        	[int($1),$_];
	} @payloads;
	my $twins = [];
	$self->tee->print("FILES\n");
	foreach my $payload(@payloads){
		my $ma = "$dir/data/".$payload->name;
		#master correct?
		if(not $self->is_ma($ma)){
			$self->tee->print(" error:master image $ma contains errors, aborting..\n");
			return 0;
		}
		#leidt ac-name af van master-name
		my $ac_name = $payload->name;
		$ac_name =~ s/(.+)_MA\.tif$/$1_AC.jp2/i;
		#nieuwe locatie van ac-name
		my $addpath = $self->choose_path;
		my $outputdir = $self->datadir."/$addpath";
               	mkpath($outputdir);
		my $ac = "$outputdir/$ac_name";
		my $file_sublocation ="$addpath/$ac_name";
		$self->tee->print("MA:$ma\n");		
		my($changed,$tmp_path) = $self->check_orientation($ma);
		if($changed){
			$self->tee->print(" msg:orientation of MA was wrong, so creating temporary file from master..\n");
			$self->tee->print(" tmpfile MA:$tmp_path\n");
			$ma = $tmp_path;
		}
		$self->tee->print(" action:$ma -> $ac [creating jpeg2000]\n");
		if(not $self->create_jp2k($ma,$ac)){
			$self->tee->print(" error:error while creating jpeg2000, aborting..\n");
			return 0;
		}
		if(not $self->is_jp2k($ac)){
			$self->tee->print(" error:newly created jpeg2000 $ac did not pass validation, aborting..\n");
		}
		my $url;
		if($self->data_prefix_url){
			$url = $self->data_prefix_url."/$addpath/$ac_name";
		}
		push @$twins,{
			ma => $ma,
			ac => $ac,
			url => $url,
			file_sublocation=>$file_sublocation
		};	 		
	}
	$self->tee->print("\nDEVS\n");
	#thumbs op basis van master-files
	my $media = [];
	my $item_id = 1;
	foreach my $twin(@$twins){
		my $path = $twin->{ma};
		my $basename=basename($path);
		my $basefile = substr($basename,0,rindex(basename($basename),'.'));
		my $added_path = $self->choose_path;
		#binnen de outputdirectory worden submappen gecreëerd
		my $outputdir = $self->thumbdir."/$added_path";
		#thumbnail
		mkpath("$outputdir/thumbnail");
		my $thumbnail = "$outputdir/thumbnail/${basefile}_thumbnail.jpeg";
		my $thumbnail_sublocation = "$added_path/thumbnail/${basefile}_thumbnail.jpeg";
		my $success = $self->create_thumb($path,$thumbnail,150);
		if(not $success){
			$self->tee->print("error while creating thumbnail $thumbnail, aborting..\n");
			return 0;
		}
		$self->tee->print("$path -> $thumbnail [thumbnail:150]\n");
		my $thumbnail_size = -s $thumbnail;
		#small
		mkpath("$outputdir/small");
		my $small = "$outputdir/small/${basefile}_small.jpeg";
		my $small_sublocation = "$added_path/small/${basefile}_small.jpeg";
		$success = $self->create_thumb($path,$small,300);
		if(not $success){
                        $self->tee->print("error while creating small $small, aborting..\n");
                        return 0;
                }		
		$self->tee->print("$path -> $small [small:300]\n");
		my $small_size = -s $small;
		#medium
		mkpath("$outputdir/medium");
		my $medium = "$outputdir/medium/${basefile}_medium.jpeg";
		my $medium_sublocation = "$added_path/medium/${basefile}_medium.jpeg";
		$success = $self->create_thumb($path,$medium,600);
		if(not $success){
                	$self->tee->print("error while creating medium $medium, aborting..\n");
                        return 0;
                }
		$self->tee->print("$path -> $medium [medium:600]\n");
		my $medium_size = -s $medium;
		#large
		mkpath("$outputdir/large");
		my $large = "$outputdir/large/${basefile}_large.jpeg";
		my $large_sublocation = "$added_path/large/${basefile}_large.jpeg";
		$success = $self->create_thumb($path,$large,1200);
                if(not $success){
                        $self->tee->print("error while creating large $large, aborting..\n");
                        return 0;
                }
		$self->tee->print("$path -> $large [large:1200]\n");
		my $large_size = -s $large;

		#prefix_url?
		my($thumbnail_url,$small_url,$medium_url,$large_url);
		if($self->thumb_prefix_url){
			$thumbnail_url = $self->thumb_prefix_url."/$added_path/thumbnail/${basefile}_thumbnail.jpeg";
			$small_url = $self->thumb_prefix_url."/$added_path/small/${basefile}_small.jpeg";
			$medium_url = $self->thumb_prefix_url."/$added_path/medium/${basefile}_medium.jpeg";
			$large_url = $self->thumb_prefix_url."/$added_path/large/${basefile}_large.jpeg";
		}
		my $info = $self->_exif->ImageInfo($twin->{ac});
		my $file_width = $info->{ImageWidth};
		my $file_height = $info->{ImageHeight};
		my $file_mime_type = $info->{MIMEType};
		$info = $self->_exif->ImageInfo($thumbnail);
		my $thumbnail_width = $info->{ImageWidth};
		my $thumbnail_height = $info->{ImageHeight};
		$info = $self->_exif->ImageInfo($small);
		my $small_width = $info->{ImageWidth};
		my $small_height = $info->{ImageHeight};
		$info = $self->_exif->ImageInfo($medium);
                my $medium_width = $info->{ImageWidth};
                my $medium_height = $info->{ImageHeight};
		$info = $self->_exif->ImageInfo($large);
                my $large_width = $info->{ImageWidth};
                my $large_height = $info->{ImageHeight};
		#maak record
		push @$media,{
			file => [{
				path => $twin->{ac},
				url => $twin->{url},
				content_type => $file_mime_type,
				size => -s $twin->{ac},
				width => $file_width,
				height => $file_height,
				tmp_sublocation => $twin->{file_sublocation}
			}],
			item_id => $item_id,
			context => 'Image',
			devs => {
				thumbnail => {
					path => $thumbnail,
					url => $thumbnail_url,
					content_type => 'image/jpeg',
					size => $thumbnail_size,
					width => $thumbnail_width,
					height => $thumbnail_height,
					tmp_sublocation => $thumbnail_sublocation
				},
                                    small => {
                                            path => $small,
					    url => $small_url,
                                            content_type => 'image/jpeg',
                                            size => $small_size,
				            width => $small_width,
				            height => $small_height,
					    tmp_sublocation => $small_sublocation
                                    },
                                    medium => {
                                            path => $medium,
					    url => $medium_url,
                                            content_type => 'image/jpeg',
                                            size => $medium_size,
					    width => $medium_width,
					    height => $medium_height,
					    tmp_sublocation => $medium_sublocation
                                    },
                                    large => {
                                            path => $large,
					    url => $large_url,
                                            content_type => 'image/jpeg',
                                            size => $large_size,
					    width => $large_width,
					    height => $large_height,
					    tmp_sublocation => $large_sublocation
                                    },
			},
			services => [
                           	"thumbnail",
                        	"small",
                                "medium",
                                "large",
				"zoomer"
                        ]
		};		
		$item_id++;
	}
	#test bestanden
	$self->tee->print("\nVALIDATING FILES\n");
	foreach my $item(@$media){
		foreach my $file(@{$item->{file}}){
			$self->tee->print($file->{path});
			my $success = $self->is_jp2k($file->{path});
			if(not $success){
				$self->tee->print($file->{path}." -> not OK,aborting..\n");
				return 0;
			}
			$self->tee->print($file->{path}." OK\n");
		}
	}
	$self->tee->print("\nVALIDATING DEVS\n");
	foreach my $item(@$media){
                foreach my $svc_id(keys %{$item->{devs}}){			
			my $file = $item->{devs}->{$svc_id}->{path};
			$self->tee->print($file);
			my $success = $self->is_jpeg($file);
			if(not $success){
                                $self->tee->print(" -> not OK,aborting..\n");
                                return 0;
                        }
                        $self->tee->print(" -> OK\n");
		}
        }
	#opslaan	
	my $record = {
		_id => $_id,
		access => {
			services => {
				thumbnail => 1,small=>1,medium=>0,large=>0,zoomer=>0,carousel=>0
			}
		},
		media => $media,
		poster_item_id => 1,
		tmp_datadir => $self->datadir,
		tmp_thumbdir => $self->thumbdir
	};
	$self->_dbout->save($record);	
	$self->tee->print("\n\nRECORD $_id STORED TO DATABASE\n");
	return 1;
}
sub now{
	my $self = shift;
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	sprintf "%4d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec;
}
sub process_list{
	my $self = shift;	
	#itereer over mappen - begin
	my $count = 0;my $succeeded=0;my $failed=0;
	$self->tee->print("BEGIN UNBAG2TMP\n\n");
	my $o_start = $self->now;
	my $o_benchmark_start=Benchmark->new();
	foreach my $dir(@{$self->_dirs}){
		my $b_start = $self->now;
		$self->tee->print("@@ bagstart\n\nBAG_NAME:".basename($dir)."\n");
		$self->tee->print("BAG_PATH:$dir\n");
		$self->tee->print("BAG_NR:$count\n");
		my $success;
		my $start = Benchmark->new();
		$success = $self->process_bag($dir);		
		my $end = Benchmark->new();
		my $diff = timediff($end,$start);
		my $b_end = $self->now;
		$self->tee->print("\nSUMMARY BAG ".basename($dir).":\n");
		$self->tee->print("\tb_start:$b_start\n");
		$self->tee->print("\tb_end:$b_end\n");
		$self->tee->print("\tb_benchmark:".timestr($diff)."\n");
		$self->tee->print("\tb_success:");
		if($success){
			$self->tee->print("true\n\n");$succeeded++;
		}else{
			$self->tee->print("false\n\n");$failed++;
			print STDERR "$dir failed, see logfile\n";
		}
		$self->tee->print("@@ bagend\n\n");
		$count++;
	}
	my $o_end = $self->now;
	my $o_benchmark_end = Benchmark->new();
	my $diff = timediff($o_benchmark_end,$o_benchmark_start);
	$self->tee->print("SUMMARY OPERATION:\n");
	$self->tee->print("\to_start:$o_start\n");
	$self->tee->print("\to_end:$o_end\n");
	$self->tee->print("\to_benchmark:".timestr($diff)."\n");
	$self->tee->print("\to_total_processed:$count\n");
	$self->tee->print("\to_total_success:$succeeded\n");
	$self->tee->print("\to_total_failed:$failed\n");
	$self->tee->print("\nEND UNBAG2TMP\n");	
}
sub filter_list{
	my $self = shift;
	opendir DIR,$self->dir or die($!);	    	                	               
	my $dirs = [];
	while(my $file = readdir(DIR)){
		my $path = $self->dir."/$file";		
		push @$dirs,$path if -d $path && $file ne "." && $file ne "..";
	}
	close DIR;
	$self->_dirs($dirs);
}
sub rm_slash{
	my($self,$str)=@_;
	if(not defined($str)){
		return "";
	}
	$str =~ s/\/$//;
	$str;
}
sub rm_slashes{
	my $self=shift;
	$self->dir($self->rm_slash($self->dir));
	$self->datadir($self->rm_slash($self->datadir));
	$self->thumbdir($self->rm_slash($self->thumbdir));
	$self->data_prefix_url($self->rm_slash($self->data_prefix_url));
	$self->thumb_prefix_url($self->rm_slash($self->thumb_prefix_url));
}
sub execute{
	my($self,$opts,$args)=@_;	
	if($self->tempdir){
		my $dirname = dirname($self->tempdir);
		if(!$dirname){
			die("$dirname does not exist!");
		}elsif(-d $self->tempdir){
			die($self->tempdir." already exists!");
		}else{
			mkdir($self->tempdir) or die($!);
		}
	}
	#kuis paden open
	$self->rm_slashes;
	#en doe je werk
	$self->filter_list;
	$self->_dbout->transaction(sub{
		$self->process_list;
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__END__

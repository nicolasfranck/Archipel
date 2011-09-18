package Catmandu::Cmd::Command::unbag;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#intern gebruik
use utf8;
use Archive::BagIt;
use File::Basename;
use Try::Tiny;
use Benchmark;
use Catmandu::Store::Simple;
use Benchmark;
use IO::Tee;
use IO::File;
use Clone qw(clone);
use File::Path qw(mkpath);


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
    documentation => "Temporary directory to store non-requestable originals [required]",
    required => 1
);
has thumbdir => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 't',
    documentation => "Temporary directory to store the thumbs [required]",
    required => 1
);
has tempdir => (
	traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'tempdir',
        documentation => "Used instead of /tmp to store temporary files",
        required => 1
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
has _dirs => (
	is => 'rw',
	isa => 'Ref',
	default => sub{[]}
);
has tee => (
	is => 'rw',
	isa => 'IO::Tee',
	lazy => 1,
	default => sub{
		my $self = shift;
		open STDERR,">/tmp/unbag-".time.".err";
		IO::Tee->new(
			\*STDOUT,
			IO::File->new(">/tmp/unbag-".time.".log")
		);
	}
);
has allowed_extensions => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'e',
	documentation => "Pattern to recognize master files",
	required => 0
);
has _stash => (
	is => 'rw',
	isa => 'HashRef',
	default => sub{
		{};
	}
);
has _mapping => (
	is => 'ro',
	isa => 'HashRef',
	default => sub{
		{
			"tif"=>"JPEG2000",
			"tiff"=>"JPEG2000",
			"mp3"=>"Audio::MP3",
			"vob"=>"MP4"
		}
	}
);
has _allowed_extensions => (
	is => 'ro',
	isa => 'Ref',
	lazy => 1,
	default => sub{
		my $self = shift;
		my $r;
		if(!$self->allowed_extensions){
			$r = '_MA';
		}else{
			$r = $self->allowed_extensions;
		}
		$r.= '.('.join('|',keys %{$self->_mapping}).')$';
		qr/$r/i;
	}
);
sub load_package {
	my($self,$package)=@_;
	Plack::Util::load_class($package);
	$package->new(
		tempdir => $self->tempdir,printer=>$self->tee
	);
}
sub get_package {
	my($self,$package)=@_;
	$self->_stash->{$package} ||= $self->load_package($package);
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
	$self->tee->print("[OK]\n");
	$self->tee->print("DC-Identifier:$_id\n\n");
	
	my @payloads = grep {$_->name =~ $self->_allowed_extensions} $self->_bagit->list_files;
	#sorteer..
	@payloads = map{
    		$_->[1];
    	}sort {
		$a->[0] <=> $b->[0]
	} map {
        	$_->name =~ /_(\d+)_MA\.\w+$/i;
        	[int($1),$_];
	} @payloads;
	my $item_id = 0;
	my $media = [];
	foreach my $payload(@payloads){
		$item_id++;
		my $ma = "$dir/data/".$payload->name;
		my $ac = $payload->name;
		$ac =~ s/(.+)_MA\.(.+)$/$1_AC/i;
		my $extension = lc substr($ma,rindex($ma,'.') + 1);
		$self->tee->print("payload [MA] $ma\n");
		if(!defined($self->_mapping->{$extension})){
			$self->tee->print("no handler defined for extension $extension\n");
			return 0;
		}
		my $handler = $self->get_package("Catmandu::Cmd::Unbag::".$self->_mapping->{$extension});
		my $item = $handler->handle({
			in => $ma,outname=>$ac,datadir => $self->datadir,thumbdir=>$self->thumbdir,
		});
		if($handler->err){
			$self->tee->print($handler->err."\n");
			return 0;
		}
		$item->{item_id} = $item_id;
		push @$media,$item;
	}
	#opslaan	
	my $record = {
		_id => $_id,
		access => {
			services => {
				thumbnail => 1,small=>1,medium=>1,large=>1,zoomer=>1,videostreaming=>1,audiostreaming=>1
			}
		},
		media => $media,
		poster_item_id => 1,
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
	$self->tempdir($self->rm_slash($self->tempdir));
}
sub check_new_dirs {
	my $self = shift;
	my $dirs = ['datadir','thumbdir','tempdir'];
	foreach my $dir(@$dirs){
		my $dirname = dirname($self->$dir);
                if(!$dirname){
                        die("$dirname does not exist!");
                }elsif(-d $self->$dir){
                        die($self->$dir." already exists!");
                }	
	}
}
sub check_existing_dirs {
	my $self = shift;
	my $dirs = ['dir'];
	foreach my $dir(@$dirs){
		die($self->$dir." does not exist!\n") if not -d $self->$dir;
	}
}
sub make_new_dirs {
	my $self = shift;
	my $dirs = ['tempdir','datadir','thumbdir'];
	foreach my $dir(@$dirs){
                mkpath($self->$dir) or die($!);
        }
}
sub execute{
	my($self,$opts,$args)=@_;	
	#kuis paden open
	$self->rm_slashes;
	$self->check_new_dirs;
	$self->check_existing_dirs;
	$self->make_new_dirs;
	#en doe je werk
	$self->filter_list;
	$self->process_list;
}

__PACKAGE__->meta->make_immutable;
no Moose;
__END__;

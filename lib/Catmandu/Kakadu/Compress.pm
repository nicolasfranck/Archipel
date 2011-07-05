package Catmandu::Kakadu::Compress;
use Moose;
use File::Basename;
use IO::CaptureOutput qw/capture_exec/;

sub BUILD{
	my $self = shift;
	#test werking
	`kdu_compress &> /dev/null`;
	if($? == -1){
		die("binaries en libs of kakadu should be added to bashrc");
	}
}

sub compress{

	my($self,%opts) = @_;	
	$opts{args}=[] if not defined($opts{args});	
	my $info={
		input => $opts{input},
		output => $opts{output}
	};		
	if(not -e $opts{input}){
		$info->{err}=1;
		$info->{errmsg}="input file ".$opts{input}." does not exist";
	}
	if(not -e dirname($opts{output})){
		$info->{err}=1;
		$info->{errmsg}="directory name of outputfile ".$opts{output}." does not exist";		
		return $info;
	}		
	my $command = "kdu_compress -i ".$opts{input}." -o ".$opts{output}." ".join(' ',@{$opts{'args'}});	
	print $command if $opts{verbose};
	my($stdout, $stderr, $success, $exit_code) = capture_exec($command);	
	if($opts{verbose}){
		print $stdout;
		print STDERR $stderr;
	}
	if($success){
		$info->{success}=1;
	}else{		
		$info->{err}=$exit_code >> 8;
		$info->{errmsg}=$stderr;
	}		
		
	return $info;
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

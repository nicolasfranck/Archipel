package Catmandu::Job::Torque;
use Moose;
use XML::Simple;
use IO::CaptureOutput qw/capture_exec/;
use JSON;
use URI::Escape;
sub submit{
	my($self,$args) = @_;
	my $cmd = "qsub ";
	if(not -e $args->{stdin}){
		die($args->{stdin});
	}
	$cmd.=" ".$args->{stdin};
	if($args->{stdout}){
		$cmd.=" -o ".$args->{stdout};
	}
	if($args->{stderr}){
		$cmd.=" -e ".$args->{stderr};
	}
	if($args->{cwd} && -d $args->{cwd}){
		$cmd.=" -d ".$args->{cwd};
	}
	if($args->{destination}){
		$cmd.=" -q ".$args->{destination};
	}	
	if($args->{priority}){
		$cmd.=" -p ".$args->{priority};
	}
	if($args->{hold}){
		$cmd.=" -h";
	}
	if($args->{vars}){
		my $vars = uri_escape(JSON::encode_json($args->{vars}));
		$cmd.=" -v perl=\"$vars\"";
	}	
	my($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	if($success){
		$stdout =~ s/\n//;		
		return $stdout,undef;
	}else{		
		return undef,$stderr;
	}
}

sub delete{
	my($self,$id)=@_;
	my $cmd = "qdel $id";
	my($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);	
	return $success;
}

sub hold{
	my($self,$id)=@_;
	my $cmd = "qdel $id";
	my($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	return $success;
}

sub release{
	my($self,$id)=@_;
	my $cmd = "qdel $id";
	my($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	return $success;
}
__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

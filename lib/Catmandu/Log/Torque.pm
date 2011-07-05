package Catmandu::Log::Torque;
use Moose;
use IO::CaptureOutput qw/capture_exec/;

has days => (
	is => 'rw',
	isa => 'Num',
	required => 0,
	default => sub{1}
);

sub trace{
	my($self,$jobid)=@_;
	if(not defined($jobid)){
		return undef;
	}
	my $cmd = "tracejob -n ".$self->days." $jobid";
	my($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	if(not $success){
		return undef;
	}
	my $job = {};
	if($stdout =~ /\buser=(\w+)\b/){
		$job->{user}=$1;
	}
	if($stdout =~ /\bgroup=(\w+)\b/){
	    $job->{group}=$1;
	}	
	if($stdout =~ /\bowner=(\w+)\b/){
		$job->{owner}=$1;
	}
	if($stdout =~ /\bjobname=(\w+)\b/){
	    $job->{jobname}=$1;
	}
	if($stdout =~ /\bqueue=(\w+)\b/){
	    $job->{queue}=$1;
	}
	if($stdout =~ /\bctime=(\w+)\b/){
	    $job->{ctime}=$1;
	}
	if($stdout =~ /\bqtime=(\w+)\b/){
		$job->{qtime}=$1;
	}
	if($stdout =~ /\betime=(\w+)\b/){
		$job->{etime}=$1;	
	}
	if($stdout =~ /\bstart=(\w+)\b/){
		$job->{start}=$1;
	}
	if($stdout =~ /\bend=(\w+)\b/){
	    $job->{end}=$1;
	}
	$job->{resources_used}={};
	if($stdout =~ /\bresources_used.mem=(\d+(b|kb|mb|gb|tb|w|kw|mw|gw|tw))\b/){
		$job->{resources_used}->{mem}=$1;
	}
	if($stdout =~ /\bresources_used.vmem=(\d+(b|kb|mb|gb|tb|w|kw|mw|gw|tw))\b/){
		$job->{resources_used}->{vmem}=$1;
	}
	if($stdout =~ /\bresources_used.walltime=(\d{2}:\d{2}:\d{2})\b/){
		$job->{resources_used}->{walltime}=$1;
	}
	if($stdout =~ /\bresources_used.cput=(\d{2}:\d{2}:\d{2})\b/){
		$job->{resources_used}->{cput}=$1;
	}
	
	return $job;
}

1;

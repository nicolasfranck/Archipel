package Catmandu::Stat::Torque;
use Moose;
use XML::Simple;
use IO::CaptureOutput qw/capture_exec/;
use JSON;
use URI::Escape;

sub jobs{
	my($self,$ids)=@_;
	my $cmd = "qstat -x ";
	if(defined($ids) && ref $ids eq "ARRAY"){
		$cmd.=join(' ',@$ids);
	}	
	my($stdout, $stderr, $success, $exit_code) = capture_exec("$cmd 2>&1");
	if($success){
		my $jobs = {};
		$stdout =~ s/<Data>//i;
		$stdout =~ s/<\/Data>//i;		
		$stdout =~ s!qstat: Unknown Job Id ((\d+)(\-\d+)?(\.[a-zA-Z0-9\-_]+)?)!<Job><Job_Id>$1</Job_Id><nonexistant>1</nonexistant></Job>!;
		$stdout = "<Data>$stdout</Data>";
		$jobs = XMLin($stdout);		
		if(not defined($jobs->{Job})){
			$jobs->{Job}=[];
		}elsif(ref $jobs->{Job} ne "ARRAY"){
			$jobs->{Job}=[$jobs->{Job}];
		}
		for(my $i = 0;$i < scalar(@{$jobs->{Job}});$i++){
			my $vars = {};			
			my @vars = split(',',$jobs->{Job}->[$i]->{Variable_List});
			foreach my $var(@vars){
				my($key,$val)=split('=',$var);
				if($key eq 'perl'){
					$vars->{$key} =JSON::decode_json(uri_unescape($val));	
				}else{
					$vars->{$key}=$val;
				}							
			}		
			$jobs->{Job}->[$i]->{vars}=$vars;							
		}
		return $jobs->{Job},undef;
	}else{		
		return undef,"$stderr";
	}
}
sub servers{
	my $self = shift;
	my $cmd = "qstat -B -f";
	my $servers = {};
	my($stdout, $stderr, $success, $exit_code) = capture_exec("$cmd 2>&1");
	if($success){
		#eerste lijn: server
		my @lines = split("\n",$stdout);
		my $server = undef;
		foreach my $line(@lines){
			$self->_trim_all(\$line);
			if($line =~ /Server: (?<server>.+)/){
				$server = $+{server};
			}
			if($line =~ /server_state = (?<server_state>.+)/i){
				$servers->{$server}->{server_state} = $+{server_state};
			}
			if($line =~ /scheduling = (?<scheduling>.+)/i){
				$servers->{$server}->{scheduling} = $+{scheduling};
			}
			if($line =~ /total_jobs = (?<total_jobs>.+)/i){
				$servers->{$server}->{total_jobs} = $+{total_jobs};
			}
			if($line =~ /state_count = (?<state_count>.+)/i){
				my @sc = split(' ',$+{state_count});
				foreach my $s(@sc){
					my($key,$val)=split(':',$s);
					$servers->{$server}->{state_count}->{$key}=$val;
				}				
			}
			if($line =~ /log_events = (?<log_events>.+)/i){
				$servers->{$server}->{log_events} = $+{log_events};
			}
			if($line =~ /mail_from = (?<mail_from>.+)/i){
				$servers->{$server}->{mail_from} = $+{mail_from};
			}
			if($line =~ /scheduler_iteration = (?<scheduler_iteration>.+)/i){
				$servers->{$server}->{scheduler_iteration} = $+{scheduler_iteration};
			}
			if($line =~ /node_check_rate = (?<node_check_rate>.+)/i){
				$servers->{$server}->{node_check_rate} = $+{node_check_rate};
			}
			if($line =~ /tcp_timeout = (?<tcp_timeout>.+)/i){
				$servers->{$server}->{tcp_timeout} = $+{tcp_timeout};
			}
			if($line =~ /pbs_version = (?<pbs_version>.+)/){
				$servers->{$server}->{pbs_version} = $+{pbs_version};
			}
			if($line =~ /next_job_number = (?<next_job_number>.+)/i){
				$servers->{$server}->{next_job_number} = $+{next_job_number};
			}
			if($line =~ /net_counter = (?<net_counter>.+)/i){
				$servers->{$server}->{net_counter} = $+{net_counter};
			}
		} 
		return $servers,undef;
	}else{
		return undef,$stderr;
	}
}
sub _trim_all{
	my($self,$stdout) = @_;
	$stdout =~ s/^\s+//;	
	$stdout =~ s/\s+$//;
	$stdout =~ s/\s\s+//;	
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

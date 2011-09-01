package Acl::VPN;
use strict;
use parent qw(Acl);
use Text::Glob qw(glob_to_regex);

sub new {
	my($class,%opts) = @_;
	my $self = $class->SUPER::new;
	$opts{allowed_range} ||= "127.0.0.*";
	$self->{allowed_range} = glob_to_regex($opts{allowed_range});
	bless $self,$class;
}

sub is_allowed {
	my($self,$env,$record,$item_id,$svc_id)=@_;
	my $allowed = 1;	
	my $sourceIP = $env->{HTTP_X_FORWARDED_FOR} ? $env->{HTTP_X_FORWARDED_FOR} : $env->{REMOTE_HOST};
        my @ips = split(',',$sourceIP);
        $sourceIP = pop(@ips);
	if(defined($record->{access}) && !$record->{access}->{services}->{$svc_id} && $sourceIP !~ $self->allowed_range){
		$allowed = 0;
	}
	return $allowed;
}
sub allowed_range {
	$_[0]->{allowed_range};
}

1;

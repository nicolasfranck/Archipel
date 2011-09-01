package PeepShow::Handler::Query::Register;
use strict;
use utf8;
use Catmandu;

sub new {
	bless {},shift;
}
sub inspect{
	my($self,$params,$confirm)=@_;

	my $hash = {params=>{},sess=>{}};
	return $hash if not $confirm;

	#params
	my $search_type = $params->{search_type};
	my $default = Catmandu->conf->{package}->{Query}->{Default};
	if(defined($search_type) && $search_type eq "advanced"){
		my $register_param_names = Catmandu->conf->{package}->{Query}->{Store}->{advanced}->{params} || [];
		foreach(@$register_param_names){
			if(defined($params->{$_})){
				$hash->{params}->{$_} = $params->{$_}
			}elsif(defined($default->{advanced}->{params}->{$_})){
				$hash->{params}->{$_} = $default->{advanced}->{params}->{$_}
			}
		}
		my $register_sess_names = Catmandu->conf->{package}->{Query}->{Store}->{advanced}->{sess} || [];		
		foreach(@$register_sess_names){
			if(defined($params->{$_})){
                                $hash->{sess}->{$_} = $params->{$_}
                        }
		}
	}else{
		my $register_param_names = Catmandu->conf->{package}->{Query}->{Store}->{simple}->{params} || [];
		foreach(@$register_param_names){
                        if(defined($params->{$_})){
                                $hash->{params}->{$_} = $params->{$_}
                        }elsif(defined($default->{simple}->{params}->{$_})){
                                $hash->{params}->{$_} = $default->{simple}->{params}->{$_}
                        }
                }
                my $register_sess_names = Catmandu->conf->{package}->{Query}->{Store}->{simple}->{sess} || [];
		foreach(@$register_sess_names){
                        if(defined($params->{$_})){
                                $hash->{sess}->{$_} = $params->{$_}
                        }
                }
	}
	#gemeenschappelijke parameters
	return $hash;
}

1;

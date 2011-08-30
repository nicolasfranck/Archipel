package Rft::Fedora;
use parent qw(Rft);

sub new {
	my($class)=@_;
	my $self = $class->SUPER::new;
	$self->{_re} = qr/^([\w_\-]+_AC)$/;
	$self->is_id(0);
	bless $self,$class;
}
sub parse {
	my($self,$rft_id)=@_;
	$self->record_id(undef);
	$self->item_id(undef);
	if(!defined($rft_id)){
                $self->error("UNDEFINED");
                return 0;
        }
	if($rft_id !~ $self->{_re}){
		$self->error("FORMAT_ERROR");
		return 0;
	}
	my $catch = $1;
	$catch =~ s/\d{4}_((\d{4})_AC)/????_\1/;
        $self->query("files:$catch");
        $self->item_id(int($2));
	return 1;
}

1;

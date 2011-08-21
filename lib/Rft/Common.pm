package Rft::Common;
use parent qw(Rft);

sub new {
	my($class)=@_;
	my $self = $class->SUPER::new;
	$self->{_re} = qr/^(\S+):(\d+)$/;
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
	$self->record_id($1);
	$self->item_id($2);
	$self->query("id:\"$1\"");
	return 1;
}

1;

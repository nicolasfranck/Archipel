package Grim::XML::Media::Reader;
use Moose;
use IO::File;
use XML::Reader;

has input => (
	is => 'rw',
	isa => 'Str',
	required => 1
);

has _xml_reader => (
	is => 'ro',
	isa => 'XML::Reader',
	lazy => 1,
	default => sub{
		XML::Reader->new(shift->input) or die($!);
	}
);

sub each{
	my($self,$callback)=@_;
	my $r = $self->_xml_reader;
	my $record;
	my $item_index;
	my $file_index;
	my $devs_index;
	my $svc_ids_index;
	while($r->iterate){
		if($r->tag eq "database" && $r->is_start){
			$record = {};
		}
		elsif($r->tag eq "record" && $r->is_start){
			$record={_id=>$r->att_hash->{id}};
		}elsif($r->tag eq "record" && $r->is_end){
			$callback->($record);
		}elsif($r->tag eq "poster_item_id" && $r->is_start){
			$record->{poster_item_id} = $r->value;
		}elsif($r->tag eq "media" && $r->is_start){
			$record->{media} = [];
			$item_index = 0;
		}elsif($r->tag eq "item" && $r->is_end){
			$item_index++;
		}elsif($r->tag eq "files" && $r->is_start){
			$record->{media}->[$item_index]->{file}=[];
			$file_index = 0;
		}elsif($r->tag eq "file" && $r->is_end){
			 $file_index++;
		}elsif($r->tag eq "path" && $r->is_start){
			$record->{media}->[$item_index]->{file}->[$file_index]->{path}=$r->value;
		}elsif($r->tag eq "content_type" && $r->is_start){
			$record->{media}->[$item_index]->{file}->[$file_index]->{content_type}=$r->value;
		}elsif($r->tag eq "devs" && $r->is_start){
			$record->{media}->[$item_index]->{devs}=[];
			$devs_index = 0;
		}elsif($r->tag eq "dev" && $r->is_start){
			$record->{media}->[$item_index]->{devs}->[$devs_index++]=$r->value;
		}elsif($r->tag eq "svc_ids" && $r->is_start){
			$record->{media}->[$item_index]->{svc_ids}=[];
			$svc_ids_index = 0;
		}elsif($r->tag eq "svc_id" && $r->is_start){
			$record->{media}->[$item_index]->{svc_ids}->[$svc_ids_index++]=$r->value;
		}elsif($r->tag eq "context" && $r->is_start){
			$record->{media}->[$item_index]->{context}=$r->value;
		}elsif($r->tag eq "access" && $r->is_start){
			$record->{media}->[$item_index]->{access}=$r->value;
		}elsif($r->tag eq "action" && $r->is_start){
                        $record->{media}->[$item_index]->{action}=$r->value;
                }
	}
}

no Moose;
1;

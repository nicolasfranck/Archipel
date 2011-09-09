package Catmandu::Cmd::Command::oai;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#nodig voor dit commando
with qw(
	Catmandu::Cmd::Opts::Grim::Harvester
);
use Clone qw(clone);
use JSON;

our @OAI_DC_ELEMENTS = qw(
    title 
    creator 
    subject 
    description 
    publisher 
    contributor 
    date
    type
    format
    identifier
    source
    language
    relation
    coverage
    rights
);


has _ua => (
        is => 'rw',
        isa => 'Ref',
        default => sub{
                LWP::UserAgent->new(cookie_jar=>{});
        }
);
has _json => (
	is => 'rw',
	isa => 'Ref',
	default => sub{
		JSON->new->pretty(1);
	}
);
sub make_metadata_record {
        my($self,$oai_record)=@_;
        my $new_metadata_record = {};
        $new_metadata_record->{$_} = $oai_record->metadata->{$_} foreach(@OAI_DC_ELEMENTS);
        $new_metadata_record->{_id} = $oai_record->header->identifier;
        return $new_metadata_record;
}
sub execute{
        my($self,$opts,$args)=@_;
	binmode(STDOUT,":encoding(utf8)");
	#harvest
	my $iterator = $self->_harvester->listAllRecords(metadataPrefix=>'oai_dc');	
	if($iterator->errorCode){
		printf STDERR "%15s : %s\n","errorCode",$iterator->errorCode;
		printf STDERR "%15s : %s\n","errorCode",$iterator->errorString;
		exit(1);
	}
	my $found = 0;
	my $imported = 0;
	my $deleted = 0;
	while(my $record = $iterator->next){
		print $record->header->identifier;
		$found++;
		if($record->header->status eq "deleted"){
			$deleted++;
			print " marked as deleted, skipping\n";
			next;
		}
		$imported++;
		print "\n";
		#print $self->_json->encode($self->make_metadata_record($record));
	}
	print "$found records found, $imported imported, $deleted marked as deleted\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

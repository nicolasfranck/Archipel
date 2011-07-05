package Grim::XML::Media::Writer;
use Moose;
use IO::File;
use XML::Writer;
use Grim::XML::Media::Record;

has output => (
	is => 'rw',
	isa => 'Str',
	required => 1,
	trigger => \&_set_writer
);
has _xml_writer => (
	is => 'rw',
	isa => 'XML::Writer',
	required => 0
);
sub new_record {
	my $self = shift;
	Grim::XML::Media::Record->new();
}
sub _set_writer {
	my $self = shift;
	my $w = XML::Writer->new(OUTPUT=>IO::File->new(">".$self->output),ENCODING=>'UTF-8',DATA_MODE => 1,DATA_INDENT => 1);
	$self->_xml_writer($w);
}
sub start_xml {
	my $self = shift;
	$self->_xml_writer->xmlDecl("UTF-8");
}
sub end_xml {
	my $self = shift;
        $self->_xml_writer->end;
}
sub start_database {
	shift->_xml_writer->startTag("database");
}
sub end_database {
	shift->_xml_writer->endTag("database");
}
sub write_record{
	my($self,$record) = @_;
	ref $record eq "Grim::XML::Media::Record" or die("record must be Grim::XML::Media::Record");
	my $w = $self->_xml_writer;
	$w->startTag("record",id=>$record->id);
		$w->startTag("poster_item_id");
		$w->characters($record->poster_item_id);
		$w->endTag("poster_item_id");
		$w->startTag("media");
		foreach my $item(@{$record->items}){
			ref $item eq "Grim::XML::Media::Record::Item" or die("item must be Grim::XML::Media::Record::Item");
			$w->startTag("item");
				$w->startTag("files");
				foreach my $pair(@{$item->file}){
					$w->startTag("file");
						$w->startTag("path");
						$w->characters($pair->{path});
						$w->endTag("path");
						$w->startTag("content_type");
                                                $w->characters($pair->{content_type});
                                                $w->endTag("content_type");
					$w->endTag("file");
				}
				$w->endTag("files");
				$w->startTag("access");
				$w->characters($item->access);
				$w->endTag("access");
				$w->startTag("context");
                                $w->characters($item->context);
                                $w->endTag("context");
				$w->startTag("svc_ids");
				foreach my $svc_id(@{$item->services}){
					$w->startTag("svc_id");
	                                $w->characters($svc_id);
        	                        $w->endTag("svc_id");
				}				
				$w->endTag("svc_ids");
				$w->startTag("devs");
                                foreach my $dev(@{$item->devs}){
                                        $w->startTag("dev");
                                        $w->characters($dev);
                                        $w->endTag("dev");
                                }
                                $w->endTag("devs");
				$w->startTag("action");
				$w->characters($item->action());
				$w->endTag("action");
				$w->startTag("title");
                                $w->characters($item->title());
                                $w->endTag("title");
				$w->startTag("item_id");
                                $w->characters($item->item_id());
                                $w->endTag("item_id");
			$w->endTag("item");
		}
		$w->endTag("media");
	$w->endTag("record");
}

no Moose;
1;

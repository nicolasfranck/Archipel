package Marc::XSLT;
use utf8;
use strict;
use XML::LibXML;
use XML::LibXSLT;

sub new {
	my($class,%opts)=@_;
	my $_source = (%opts && $opts{source})?  XML::LibXML->load_xml(%{$opts{source}}):undef;
	my $_style = (%opts && $opts{style})? XML::LibXML->load_xml(%{$opts{style}}):undef;
	bless {
		content_type => "application/xml",
		_source => $_source,
		_style => $_style,
		_xslt => XML::LibXSLT->new
	},$class;
}
sub content_type {
	my $self = shift;
        if(@_){$self->{content_type}=shift;}
        $self->{content_type};
}
sub _source {
	my $self = shift;
	if(@_){$self->{_source}= XML::LibXML->load_xml(string => shift);}
	$self->{_source};
}
sub _style {
	my $self = shift;
	if(@_){$self->{_style}= XML::LibXML->load_xml(location=>shift);}
	$self->{_style};
}
sub _xslt {
	my $self = shift;
	if(@_){$self->{_xslt}=shift;}
	$self->{_xslt};
}
sub transform{
	my $self = shift;
	my $stylesheet = $self->_xslt->parse_stylesheet($self->_style);
  	my $results = $stylesheet->transform($self->_source);
	$stylesheet->output_as_chars($results);
}

1;

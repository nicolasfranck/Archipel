package Marc::XSLT::SRW;
use strict;
use utf8;
use parent qw(Marc::XSLT);
use File::Basename;

sub transform{
	my($self,$xml)=@_;
	my $dirname = dirname(__FILE__);
	$self->_source($xml);
	$self->_style("$dirname/MARC21slim2SRWDC.xsl");
	$self->SUPER::transform;
}

1;

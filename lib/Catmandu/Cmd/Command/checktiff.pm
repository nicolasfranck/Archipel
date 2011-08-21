package Catmandu::Cmd::Command::checktiff;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

with qw(
        Catmandu::Cmd::Opts::Grim::Store::Media
        Catmandu::Cmd::Opts::Grim::Exif::Image
);
use Catmandu::Store::Simple;

has _media => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                Catmandu::Store::Simple->new(%{shift->media_arg});
        }
);

sub execute{
        my($self,$opts,$args)=@_;
	$self->_media->each(sub{
		my $record = shift;
		print $record->{_id}."\n";
		foreach my $item(@{$record->{media}}){
			foreach my $file(@{$item->{file}}){				
				next if $file->{content_type} ne "image/tiff";
				if($self->is_tiff($file->{path})){
					print $file->{path}." [VALID PYRAMID TIFF]\n";
				}else{
					print $file->{path}." [NOT A VALID PYRAMID TIFF]\n";
				}
			}
		}
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

package Catmandu::Cmd::Command::devs;
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
has id => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'Str',
	cmd_aliases => 'r',
	documentation => "list only files of this id",
	required => 0
);
sub print_devs{
	my($self,$record)=@_;
	foreach my $item(@{$record->{media}}){
        	foreach my $svc_id(keys %{$item->{devs}}){
                	print $item->{devs}->{$svc_id}->{url}."\n";
                }
        }
}
sub execute{
        my($self,$opts,$args)=@_;
	if(defined($self->id)){
		my $record = $self->_media->load($self->id);
		$self->print_devs($record) if defined($record);
	}else{
		$self->_media->each(sub{
			$self->print_devs(shift);
		});
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

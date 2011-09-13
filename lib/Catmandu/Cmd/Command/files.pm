package Catmandu::Cmd::Command::files;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

use Catmandu::Store::Simple;
with qw(
	Catmandu::Cmd::Opts::Grim::Store::Media
);

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
sub print_files{
	my($self,$record)=@_;
	foreach my $item(@{$record->{media}}){
		foreach my $file(@{$item->{file}}){
        		print $file->{path}."\n" if $file->{path};
	       	}
	}
}
sub execute{
        my($self,$opts,$args)=@_;
	if(defined($self->id)){
		my $record = $self->_media->load($self->id);
		$self->print_files($record) if defined($record);
	}else{
		$self->_media->each(sub{
			$self->print_files(shift);
		});
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

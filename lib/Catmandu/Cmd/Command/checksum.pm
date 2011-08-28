package Catmandu::Cmd::Command::checksum;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;
extends qw(Catmandu::Cmd::Command);

with qw(
	Catmandu::Cmd::Opts::Grim::Store::Media
);
use Catmandu::Store::Simple;
use Digest::MD5 qw(md5_hex);

has _media => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                Catmandu::Store::Simple->new(%{shift->media_arg});
        }
);
sub validate_checksum {
	my($self,$file,$checksum)=@_;
	open FILE,"<$file" or die($!);
	my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
	close FILE;
	$md5 eq $checksum;
}
sub execute{
        my($self,$opts,$args)=@_;
	$self->_media->each(sub{
		my $record = shift;
		print $record->{_id}."\n";
		foreach my $item(@{$record->{media}}){
			print "\tfiles:\n";
			foreach my $file(@{$item->{file}}){
				my $path = $file->{path};
				next if !defined($path);
				my $checksum = $file->{md5_checksum};
				next if !defined($checksum);
				print "\t$path ";
				print $self->validate_checksum($path,$checksum)? "OK\n":"NOT OK\n";
			}
			print "\tderivatives:\n";
			foreach my $svc_id(keys %{$item->{devs}}){
				my $path = $item->{devs}->{$svc_id}->{path};				
				next if !defined($path);
				my $checksum = $item->{devs}->{$svc_id}->{md5_checksum};
				next if !defined($checksum);
                                print "\t$path ";
                                print $self->validate_checksum($path,$checksum)? "OK\n":"NOT OK\n";
			}
		}
	});
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;	

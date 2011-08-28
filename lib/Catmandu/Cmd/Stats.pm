package Catmandu::Cmd::Stats;
use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub new {
	my($class)=@_;
	bless {},$class;
	
}
sub stat_properties {
	my($self,$filename)=@_;
	my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)=stat($filename);
	open FILE,"<$filename" or die($!);
	my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
	close FILE;
	return {
		size => $size,
		date_created => $ctime,
		date_accessed=>$atime,
		date_modified=>$mtime,
		md5_checksum => $md5,
		path => $filename
	};
}
1;

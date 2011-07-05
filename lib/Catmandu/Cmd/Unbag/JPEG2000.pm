package Catmandu::Cmd::Unbag::JPEG2000;
use strict;
use parent qw(Catmandu::Cmd::Unbag);

use Data::UUID;
use Switch;
use File::Path qw(mkpath rmtree);
use File::Copy;
use List::Util qw(min max sum);
use IO::CaptureOutput qw(capture_exec);
use Image::Magick;
use Image::Magick::Thumbnail::Simple;
#attributen
sub new {
	my($class,%opts) = @_;
	my $self = $class->SUPER::new(%opts);
	$self->{magick}=Image::Magick->new;
	$self->{thumber}=Image::Magick::Thumbnail::Simple->new;
	$self->{devs}->{medium} = {axis=>600};
	$self->{devs}->{large} = {axis=>1200};
	bless $self,$class;
}
sub magick {
	shift->{magick};
}
sub thumber {
	shift->{thumber};
}
#functionaliteit
#is-functies
sub is_ma{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if uc($info->{FileType}) ne "TIFF";
        return 0 if $info->{MIMEType} ne "image/tiff";
        return 1;
}
sub is_jp2k{
        my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
        my $info = $self->exif->ImageInfo($file);
        return 0 if defined($info->{Error});
        return 0 if $info->{FileType} ne "JP2";
        return 0 if $info->{MIMEType} ne "image/jp2";
        return 1;
}
#check functies
sub check_orientation{
        my($self,$path)=@_;
        @{$self->magick} = ();
        my $changed = 0;
        my $tmp_path = undef;
        my $info = $self->exif->ImageInfo($path);
        if($info->{Orientation} ne "Horizontal (normal)"){
		$self->print("orientation wrong\n");
                $tmp_path = $self->tempdir."/".Data::UUID->new->create_str.".tif";
                $self->magick->Read($path);
                $self->magick->AutoOrient();
                $self->magick->Write($tmp_path);
                $changed = 1;
		$self->print("[NEW MA] $tmp_path\n");
        }
        return $changed,$tmp_path;
}
sub test_file {
	my($self,$file_info)=@_;
	$self->is_jp2k($file_info->{file});
}
sub test_devs {
	my($self,$devs_info)=@_;
	foreach my $type(keys %$devs_info){
		if(!$self->is_jpeg($devs_info->{$type}->{file})){
			$self->err($devs_info->{$type}->{file}." is not a valid jpeg");
			return undef;
		}
		$self->print("[TEST JPEG] ".$devs_info->{$type}->{file}." [VALID JPEG]\n");
	}
	return 1;
}
#create-functie
sub create_thumb{
        my($self,$input,$output,$size)=@_;
        my $success = $self->thumber->thumbnail(
                input => $input,
                output => $output,
                size => $size
        );
	$self->out(undef);
	if($success){
		$self->err(undef);
		$self->exitcode(0);
	}else{
		$self->err($self->thumber->error);
		$self->exitcode(1);
	}
	return $success;
}
sub create_jp2k{
        my($self,$input,$output)=@_;
        my $info = $self->exif->ImageInfo($input);
        my $width = $info->{ImageWidth};
        my $height = $info->{ImageHeight};
        my $max = max($width,$height);
        my $temp;
        if($max > 4000){
		$self->print("too big, resizing..\n");
                $temp = $self->tempdir."/".Data::UUID->new->create_str.'.tif';
		$self->print("[MA TIFF] $input -> [RESIZED TIFF] $temp\n");
                my $success = $self->create_thumb($input,$temp,4000);
                if(not $success){
                        $self->err("error:error while storing pyramid in temporary file $temp","\n");
                        unlink($temp) if -f $temp;
                        return undef;
                }
                $input = $temp;
        }
        my $rate = sum(split(' ',$info->{BitsPerSample}));
        if($rate > 32){
                $rate = "24,32";
        }
        my $command = "kdu_compress -i $input Stiles='{256,256}' Clevels=8 Clayers=8 -rate $rate Creversible=yes Corder=RPCL -no_weights -o $output";
        $self->print("$command\n");
        my($stdout, $stderr, $success, $exit_code) = capture_exec($command);
        if(not $success){
                $self->err($stderr);
                unlink($output) if -f $output;
        }
        unlink($temp) if defined($temp) && -f $temp;
        return $success;
}
sub create_file {
	my($self,$opts)=@_;
	my $sublocation = $self->choose_path;
	if(!mkpath($opts->{datadir}."/$sublocation")){
		$self->err($!);
		return undef;
	}
	my $out = $opts->{datadir}."/$sublocation/".$opts->{outname}.".jp2";
#        my($changed,$tmp_path) = $self->check_orientation($opts->{in});
#        if($changed){
#                $opts->{in} = $tmp_path;
#        }
	$self->print("[MA TIFF] ".$opts->{in}." -> $out [JPEG2000]\n");
        if(not $self->create_jp2k($opts->{in},$out)){
                return undef;
        }
        if(not $self->is_jp2k($out)){
		return undef;	
        }
	my $file_info= {
		file=>$out,info=>$self->exif->ImageInfo($out),
		file_sublocation => "$sublocation/".$opts->{outname}.".jp2"
	};
	$file_info->{url} = $opts->{data_prefix_url}.$file_info->{file_sublocation} if($opts->{data_prefix_url});
	return $file_info;
}
sub create_dev {
	my($self,$in,$out,$type)=@_;
	if(!defined($self->devs->{$type})){
		$self->err("$type not supported for JPEG2000\n");
		return undef;
	}
	my $success = $self->create_thumb($in,$out,$self->devs->{$type}->{axis});
	return undef if not $success;
	return {
		file => $out,info=>$self->exif->ImageInfo($out)
	};
}
sub create_devs {
	my($self,$opts)=@_;
	my $sublocation = $self->choose_path;
	if(!mkpath($opts->{thumbdir}."/$sublocation")){
		$self->err($!);
		return undef;
	}
	my $devs_info = {};
	foreach my $type(keys %{$self->devs}){
		my $out = $opts->{thumbdir}."/$sublocation/".$opts->{outname}."_$type.jpeg";
		$self->print("[TIFF] $opts->{in} -> $out [JPEG $type]\n");
		my $i = $self->create_dev($opts->{in},$out,$type);
		return undef if $self->err;
		$i->{file_sublocation} = "$sublocation/".$opts->{outname}."_$type.jpeg";
		$i->{url} = $opts->{thumb_prefix_url}."/".$i->{file_sublocation} if defined($opts->{thumb_prefix_url});
		$devs_info->{$type}=$i;
	}
	return $devs_info;
}
sub make_item {
	my($self,$file_info,$devs_info)=@_;
	my $item = {
		file => [{
                        path => $file_info->{file},
                        url => $file_info->{url},
                        content_type => $file_info->{info}->{MIMEType},
                        size => -s $file_info->{file},
                        width => $file_info->{info}->{ImageWidth},
                        height => $file_info->{info}->{ImageHeight},
                        tmp_sublocation => $file_info->{file_sublocation}
                }],
                context => 'Image',
		services => [
                        "thumbnail",
                        "small",
                        "medium",
                        "large",
                        "zoomer",
			"carousel"
                ]
	};
	foreach my $type(keys %$devs_info){
		$item->{devs}->{$type} = {
                        path => $devs_info->{$type}->{file},
                        url => $devs_info->{$type}->{url},
                        content_type => $devs_info->{$type}->{info}->{MIMEType},
                        size => -s $devs_info->{$type}->{file},
                        width => $devs_info->{$type}->{info}->{ImageWidth},
                        height => $devs_info->{$type}->{info}->{ImageHeight},
                        tmp_sublocation => $devs_info->{$type}->{file_sublocation}
                };
	}
	return $item;
}
sub handle {
	my($self,$opts)=@_;
	$self->print("HANDLER JPEG2000 REACHED\n");
	if(!$self->is_ma($opts->{in})){
		$self->err("invalid master");
		return undef;
	}
	my $file_info = $self->create_file($opts);
	if($self->err){
		$self->print($self->err);
		return undef;
	}
	$self->print("[TEST JPEG2000] ".$file_info->{file}."\n");
	if(!$self->test_file($file_info)){
		$self->print($self->err);
		return undef;
	}
	$self->print("[JPEG2000] ".$file_info->{file}." [VALID JPEG2000]\n");
	my $devs_info = $self->create_devs($opts);
	if($self->err){
                $self->print($self->err);
                return undef;
        }
	if(!$self->test_devs($devs_info)){
		$self->print($self->err);
		return undef;
	}
	my $item = $self->make_item($file_info,$devs_info);
}


1;

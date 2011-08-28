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

my $rgb_profile = "../profiles/Adobe ICC Profiles/RGB Profiles/sRGB Color Space Profile.icm";

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
#sub unsharp {
#	my($self,$in,$out)=@_;
#	@{$self->magick} = ();
#        $self->magick->Read($in);
#        $self->magick->UnsharpMask(radius=>6,sigma=>3,amount=>1,threshold=>0);
#        $self->magick->Write($out);
#	return 1;
#}
sub to_rgb {
        my($self,$in,$out)=@_;
        @{$self->magick} = ();
        $self->magick->Read($in);
        $self->magick->Profile(name=>$rgb_profile);
        $self->magick->Write($out);
        return (1,undef);
}
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
        my($self,$input,$input_info,$output)=@_;
        my $rate = sum(split(' ',$input_info->{BitsPerSample}));
        if($rate > 32){
                $rate = "24,32";
        }
	my $command = "kdu_compress -i $input Stiles='{256,256}' Clevels=8 Clayers=8 -rate $rate Corder=RPCL -no_weights -o $output";
        $self->print("$command\n");
        my($stdout, $stderr, $success, $exit_code) = capture_exec($command);
        if(not $success){
                $self->err($stderr);
                unlink($output) if -f $output;
        }
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
	my $temp;
	my $copy;
	#werk altijd op een kopie!
	$copy = $self->tempdir."/".Data::UUID->new->create_str.".tif";
	$self->print("--> copying ".$opts->{in}." to $copy\n");
	my $status = copy($opts->{in},$copy);
	if(!$status){
		$self->err($!);
		return  undef;
	}	
	#profile
	$temp = $self->tempdir."/".Data::UUID->new->create_str.".tif";
	$self->print("--> converting to sRGB: $copy -> $temp\n");
	my($success,$err)=$self->to_rgb($copy,$temp);
	$self->err($err);
	if(!$success){
		unlink($temp) if -f $temp;
		unlink($copy) if -f $copy;
		return 0;
	}
	unlink($copy);
	$copy = $temp;
	$self->print("--> copy is now $copy\n");
	#resize
	my $info = $self->exif->ImageInfo($copy);
        my $width = $info->{ImageWidth};
        my $height = $info->{ImageHeight};
        my $max = max($width,$height);
        if($max > 4000){
                $self->print("--> axis $max is too big, resizing..\n");
                $temp = $self->tempdir."/".Data::UUID->new->create_str.'.tif';
                $self->print("[MA TIFF] $copy -> [RESIZED TIFF] $temp\n");
                my $success = $self->create_thumb($copy,$temp,4000);
                if(not $success){
                        unlink($temp) if -f $temp;
			unlink($copy) if -f $copy;
                        return undef;
                }
		unlink($copy);
		$copy=$temp;
		$self->print("--> copy is now $copy\n");
        }
	#unsharp mask
#	$temp = $self->tempdir."/".Data::UUID->new->create_str.'.tif';
#	$self->print("--> applying unsharp mask: $copy -> $temp\n");
#	if(!$self->unsharp($copy,$temp)){
#		unlink($temp) if -f $temp;
#                unlink($copy) if -f $copy;
#                return undef;
#	}
#	unlink($copy);
#	$copy = $temp;
#	$self->print("--> copy is now $copy\n");
	#jpeg2000
	$self->print("[MA TIFF] $copy -> $out [JPEG2000]\n");
        if(not $self->create_jp2k($copy,$info,$out)){
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
	return $file_info,$copy;
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
	my $stat_properties = $self->stat_properties($file_info->{file});
	my $item = {
		file => [{
			%$stat_properties,
                        url => $file_info->{url},
                        content_type => $file_info->{info}->{MIMEType},
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
		$stat_properties = $self->stat_properties($devs_info->{$type}->{file});
		$item->{devs}->{$type} = {
			%$stat_properties,
                        url => $devs_info->{$type}->{url},
                        content_type => $devs_info->{$type}->{info}->{MIMEType},
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
	my($file_info,$copy) = $self->create_file($opts);
	$opts->{in} = $copy;
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
	$self->print("--> deleting copy $copy\n");
	unlink($copy) if -f $copy;
	my $item = $self->make_item($file_info,$devs_info);	
}


1;

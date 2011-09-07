package Catmandu::Cmd::Unbag::Video::FLV;
use strict;
use parent qw(Catmandu::Cmd::Unbag);

use Clone qw(clone);
use Data::UUID;
use File::Path qw(mkpath rmtree);
use File::Copy;
use List::Util qw(min max sum);
use IO::CaptureOutput qw(capture_exec);
use Video::FFmpeg;
use FFmpeg::Command;

my $config = {
	options => {
		'-f' => 'flv',
		#enkel h.264 en flv zijn streambare videoformaten
		'-vcodec' => 'libx264',
		#CBR (constant bitrate) is noodzakelijk voor streaming
		'-b' => '200k',
		'-minrate' => '200k',
		'-maxrate' => '200k',
		'-bufsize' => '100k',
		#GOP (-g) zorgt voor keyframes
		'-r' => 25,
		'-g' => 50,
		'-s' => '640x480',
		'-acodec' => 'libmp3lame',
		'-ab' => 64000,
		'-ac' => 1		
	},
	check_video => {
		codec => 'h264',fps => 25,width=>640,height=>480
	},
	check_audio => {
                codec => 'mp3',bit_rate => 64000,channels => 1
        }
};
#attributen
sub new {
	my($class,%opts) = @_;
	my $self = $class->SUPER::new(%opts);
	$self->{av}=undef;
	$self->{ffmpeg}=FFmpeg::Command->new;
	bless $self,$class;
}
sub av {
	my $self = shift;
	if(@_){$self->{av} = defined($_[0]) && -f $_[0] ? Video::FFmpeg::AVFormat->new($_[0]):undef;}
	$self->{av};
}
sub ffmpeg {
	shift->{ffmpeg};
}
sub conf {
	$config;
}
#functionaliteit
#is-functies
sub is_ma {
	#dummy -> nog niet duidelijk waaraan zo'n master voldoen
	return 1;
}
sub is_flv {
	my($self,$file)=@_;
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
	#bestandsinformatie
        my $info = $self->exif->ImageInfo($file);
        return 0 if defined($info->{Error});
	return 0 if $info->{FileType} ne "FLV";
        return 0 if $info->{MIMEType} ne "video/x-flv";
	#check streams
	$self->av($file);
	my @video = $self->av->video || ();
	if(scalar(@video) <= 0){
		$self->err("no video stream detected!");
		return 0;
	}elsif(scalar(@video)>1){
                $self->err("only one video stream allowed!");
                return 0;
        }
	my @audio = $self->av->audio || ();
	if(scalar(@audio)<= 0){
                $self->err("no audio stream detected!");
                return 0;
        }elsif(scalar(@audio)>1){
		$self->err("only one audio stream allowed!");
		return 0;
	}
	foreach my $key(keys %{$self->conf->{check_video}}){
		my $value = $video[0]->$key;
                my $check = $self->conf->{check_video}->{$key};
                if($check =~ /^\d+$/){
                        if($value > $check){
                                $self->err("$key $value in video incorrect, should be equal or less to $check");
                                return 0;
                        }
                }else{
                        if($value ne $check){
                                $self->err("$key $value in video incorrect, should be $check");
                                return 0;
                        }
                }
	}
	foreach my $key(keys %{$self->conf->{check_audio}}){
		my $value = $audio[0]->$key;
		my $check = $self->conf->{check_audio}->{$key};
		if($check =~ /^\d+$/){
			if($value > $check){
				$self->err("$key $value in audio incorrect, should be equal or less to $check");
				return 0;
			}
		}else{
	                if($value ne $check){
        	                $self->err("$key $value in audio incorrect, should be $check");
				return 0;
	                }
		}
        }
	$self->av(undef);
        return 1;
}
#check functies
sub test_file {
	my($self,$file_info)=@_;
	$self->is_flv($file_info->{file});
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
#create-functies
sub flv_fix {
	my($self,$input,$output)=@_;
	my $command = "flvtool++ -nodump $input $output";
        my($stdout, $stderr, $success, $exit_code) = capture_exec($command);
	$self->err($stderr);
	$success;
}
sub create_flv {
	my($self,$in,$out)=@_;
	my $options = clone($self->conf->{options});
	$self->av($in);
	my $audio = $self->av->audio;
	my $video = $self->av->video;
	if($audio->bit_rate < $options->{'-ab'}){
		$options->{'-ab'} = $audio->bit_rate;
	}
	#log input - begin
	$self->print("\tinput video stream:\n");
	$self->print("\t\tcodec:".$video->codec."\n");
	$self->print("\t\twidth:".$video->width."\n");
	$self->print("\t\theight:".$video->height."\n");
	$self->print("\t\tfps:".$video->fps."\n");
	$self->print("\t\tdisplay aspect:".$video->display_aspect."\n");
	$self->print("\t\tpixel aspect:".$video->pixel_aspect."\n");
	$self->print("\tinput audio stream:\n");
	$self->print("\t\tcodec:".$audio->codec."\n");
        $self->print("\t\tbit rate:".$audio->bit_rate."\n");
        $self->print("\t\tchannels:".$audio->channels."\n");
	#log input - end
	#log output - start
	$self->print("\toutput parameters:\n");
	$self->print("\t\t$_:".$options->{$_}."\n") foreach(keys %$options);
	#log output - end
	$self->ffmpeg->input_file($in);
	$self->ffmpeg->output_file($out);
	$self->ffmpeg->options(%$options);
	my $success = $self->ffmpeg->exec;
	#tja, ffmpeg genereert graag warnings..
	if(!$success){
		$self->err($self->ffmpeg->errstr);
	}else{
		my $temp = $self->tempdir."/".Data::UUID->new->create_str.".flv";
		$self->print("creating temporary file for flv fix:$temp\n");
		$success = $self->flv_fix($out,$temp);
		if(!$success){
			unlink($out) if -f $out;
			unlink($temp) if -f $temp;
		}else{
			$self->print("moving temporary file $temp to $out\n");
			$self->err(undef);
			$success = move($temp,$out);
			$self->err($!) if !$success;
		}
	}
	return $success;
	
}
sub create_thumb{
        my($self,$input,$output,$size)=@_;
	my $command = "ffmpegthumbnailer -i $input -o $output -s $size";
	my($stdout, $stderr, $success, $exit_code) = capture_exec($command);
	#ffmpeg genereert graag warnings die niet altijd van belang zijn..
	if(!$success){
		$self->err($stderr);
	}else{
		$self->err(undef);
	}
	$self->out($stdout);
	return $success;
}
sub create_file {
	my($self,$opts)=@_;
	my $sublocation = $self->choose_path;
	if(!mkpath($opts->{datadir}."/$sublocation")){
		$self->err($!);
		return undef;
	}
	my $out = $opts->{datadir}."/$sublocation/".$opts->{outname}.".flv";
	$self->print("[MA] ".$opts->{in}." -> $out [FLV]\n");
        if(!$self->create_flv($opts->{in},$out)){
                return undef;
        }
	my $file_info= {
		file=>$out,info=>$self->exif->ImageInfo($out),
	};
	return $file_info;
}
sub create_dev {
	my($self,$in,$out,$type)=@_;
	if(!defined($self->devs->{$type})){
		$self->err("$type not supported for Video\n");
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
		$self->print("[VIDEO] $opts->{in} -> $out [JPEG $type]\n");
		my $i = $self->create_dev($opts->{in},$out,$type);
		return undef if $self->err;
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
                        content_type => $file_info->{info}->{MIMEType},
                        width => $file_info->{info}->{ImageWidth},
                        height => $file_info->{info}->{ImageHeight},
                }],
                context => 'Video',
		services => [
                        "thumbnail",
                        "small",
                        "videostreaming"
                ]
	};
	foreach my $type(keys %$devs_info){
		$stat_properties = $self->stat_properties($devs_info->{$type}->{file});
		$item->{devs}->{$type} = {
			%$stat_properties,
                        content_type => $devs_info->{$type}->{info}->{MIMEType},
                        width => $devs_info->{$type}->{info}->{ImageWidth},
                        height => $devs_info->{$type}->{info}->{ImageHeigth},
                };
	}
	return $item;
}
sub handle {
	my($self,$opts)=@_;
	$self->print("HANDLER Video REACHED\n");
	if(!$self->is_ma($opts->{in})){
		$self->print($self->err);
		return undef;
	}
	my $file_info = $self->create_file($opts);
	if($self->err){
		$self->print($self->err);
		return undef;
	}
	$self->print("[TEST Video] ".$file_info->{file});
	if(!$self->test_file($file_info)){
		$self->print($self->err);
		return undef;
	}
	$self->print("[VALID Video]\n");
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

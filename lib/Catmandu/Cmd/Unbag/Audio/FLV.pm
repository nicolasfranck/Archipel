package Catmandu::Cmd::Unbag::Audio::FLV;
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
		'-vn' => 1,
		'-acodec' => 'libmp3lame',
		'-ab' => 64000,
		'-ac' => 1		
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
	$_[0]->{ffmpeg};
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
	my @audio = $self->av->audio || ();
	if(scalar(@audio)<= 0){
                $self->err("no audio stream detected!");
                return 0;
        }elsif(scalar(@audio)>1){
		$self->err("only one audio stream allowed!");
		return 0;
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
sub create_flv {
	my($self,$in,$out)=@_;
	my $options = clone($self->conf->{options});
	$self->av($in);
	my $audio = $self->av->audio;
	if($audio->bit_rate < $options->{'-ab'}){
		$options->{'-ab'} = $audio->bit_rate;
	}
	#log input - begin
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
	my $out = $opts->{datadir}."/$sublocation/".$opts->{outname}.".flv";
	$self->print("[MA] ".$opts->{in}." -> $out [FLV]\n");
        if(!$self->create_mp4($opts->{in},$out)){
                return undef;
        }
	my $file_info= {
		file=>$out,info=>$self->exif->ImageInfo($out),
	};
	return $file_info;
}
sub make_item {
	my($self,$file_info)=@_;
	my $stat_properties = $self->stat_properties($file_info->{file});
	my $item = {
		file => [{
			%$stat_properties,
                        url => $file_info->{url},
                        content_type => $file_info->{info}->{MIMEType},
                        width => $file_info->{info}->{ImageWidth},
                        height => $file_info->{info}->{ImageHeight},
                }],
                context => 'Audio',
		devs => {},
		services => ["audiostreaming"]
	};
	return $item;
}
sub handle {
	my($self,$opts)=@_;
	$self->print("HANDLER Audio::FLV REACHED\n");
	if(!$self->is_ma($opts->{in})){
		$self->print($self->err);
		return undef;
	}
	my $file_info = $self->create_file($opts);
	if($self->err){
		$self->print($self->err);
		return undef;
	}
	$self->print("[TEST FLV] ".$file_info->{file});
	if(!$self->test_file($file_info)){
		$self->print($self->err);
		return undef;
	}
	$self->print("[VALID FLV]\n");
	my $item = $self->make_item($file_info);
}


1;

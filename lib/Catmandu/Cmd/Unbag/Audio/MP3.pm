package Catmandu::Cmd::Unbag::Audio::MP3;
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
		'-acodec' => 'libmp3lame',
		'-ab' => 128000,
		'-ac' => 3		
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
sub is_mp3 {
	my($self,$file)=@_;
	$self->print("validating file $file..\n");
        return 0 if not defined($file);
        return 0 if not -f $file;
        return 0 if -s $file == 0;
	#bestandsinformatie
        my $info = $self->exif->ImageInfo($file);
        return 0 if defined($info->{Error});
	return 0 if $info->{FileType} ne "MP3";
	$self->print("filetype correct\n");
        return 0 if($info->{MIMEType} !~ /audio\/(x-)?mpeg((-)?3)?/);
	$self->print("mimetype correct\n");
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
	$self->av(undef);
        return 1;
}
#check functies
sub test_file {
	my($self,$file_info)=@_;
	$self->is_mp3($file_info->{file});
}
sub create_mp3 {
	my($self,$in,$out)=@_;
	my $options = clone($self->conf->{options});
	$self->av($in);
	my $audio = $self->av->audio;
	if($audio->bit_rate < $options->{'-ab'}){
		$options->{'-ab'} = $audio->bit_rate;
	}
	if($audio->channels < $options->{'-ac'}){
		$options->{'-ac'} = $audio->channels;
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
	my $out = $opts->{datadir}."/$sublocation/".$opts->{outname}.".mp3";
	$self->print("[MA] ".$opts->{in}." -> $out [MP3]\n");
        if(!$self->create_mp3($opts->{in},$out)){
                return undef;
        }
	my $file_info= {
		file=>$out,info=>$self->exif->ImageInfo($out),
	};
	return $file_info;
}
sub make_item {
	my($self,$file_info)=@_;
	$self->print("making item..\n");
	my $stat_properties = $self->stat_properties($file_info->{file});
	my $item = {
		file => [{
			%$stat_properties,
                        content_type => $file_info->{info}->{MIMEType},
                        width => $file_info->{info}->{ImageWidth},
                        height => $file_info->{info}->{ImageHeight},
                }],
                context => 'Audio',
		devs => {},
		services => ["thumbnail","audiostreaming"]
	};
	return $item;
}
sub handle {
	my($self,$opts)=@_;
	$self->print("HANDLER ".__PACKAGE__." REACHED\n");
	if(!$self->is_ma($opts->{in})){
		$self->print($self->err);
		return undef;
	}
	my $file_info = $self->create_file($opts);
	if($self->err){
		$self->print($self->err);
		return undef;
	}
	$self->print("[TEST MP3] ".$file_info->{file});
	if(!$self->test_file($file_info)){
		$self->print($self->err);
		return undef;
	}
	$self->print("[VALID MP3]\n");
        my $item = $self->make_item($file_info);
}


1;

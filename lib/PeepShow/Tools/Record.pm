package PeepShow::Tools::Record;
use Exporter qw(import);
@EXPORT=qw(shortenValues filter slice);

sub shortenValues{
	my($record,$key,$length)=@_;	
	for($i=0;$i < scalar(@$record);$i++){
		my $slength = $length - 2;		
		if(length($record->[$i]->{$key}) > $length){			
			$record->[$i]->{$key} = substr($record->[$i]->{$key},0,$slength)."..";
		}
	}
}
sub filter{
	my($array,$filter)=@_;
	my $newarray=[];
	my($key,$value)=%$filter;
	my $length = scalar(@{$array});
	for($i=0;$i < $length;$i++){
		if($array->[$i]->{$key} eq $value){
			push @$newarray,$array->[$i];
		}
	}	
	return $newarray;
}

sub slice{
	my($array,$offset,$limit)=@_;
	my $newarray = [];	
	if(not defined($array->[$offset])){
		return $newarray;
	}
	my $length = scalar(@$array);
	$start = (int($offset) > 0 && $offset <= $length -1)? $offset:0;
	$end = (($offset+$limit-1)<=$length-1)? $offset+$limit-1:$length-1;	
	return [@{$array}[$start..$end]];
}

1;

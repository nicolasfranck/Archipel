package Catmandu::Cmd::Opts::Grim::Index::Make;
use utf8;
use Moose::Role;
use Set::Object;
use Text::Unaccent::PurePerl;
use Encode;
use YAML;
use File::Basename;
use Try::Tiny;
use Data::Dumper;

has yaml_index_arg => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'y',
        documentation => "YAML configuration file for the index"
);
has _yaml_index => (
        is =>'ro',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                my $hash;
                try{
                        $hash = YAML::LoadFile($self->yaml_index_arg or "../yaml/aleph.yml");
                }catch{
                        print $_;
                        $hash = {};
                };
                $hash;
        }
);
sub one_array {
        my($self,$value) = @_;
        my @array = ();
        if(ref $value eq "ARRAY"){
                foreach(@$value){
                        push @array,($self->one_array($_));
                }
        }else{
                push @array,$value;
        }
        return @array;
}
sub unaccent {
        my($self,$oct) = @_;
        #encode("utf8", unac_string($oct));
	#nog niet in utf8 encoderen, want alles wordt later nog eens geëncodeerd!
	unac_string($oct);
}
sub clean{
        my($self,$value)=@_;
        $value = "" if not defined($value);
        $value =~ s/\s//g;#compacteren
        $value = $self->unaccent($value);#accenten verwijderen
        $value = lc($value);#lowercase
        $value =~ s/[^a-z0-9]//g;#eenmaal accenten verwijderd (vb. é -> e), mogen niet alphanumerieke karakters eruit
        $value = substr($value,0,80);#tja, we overdrijven niet met het aantal karakters waarop we sorteren..
}
sub make_index_merge {
        my($self,$a,$b)=@_;
        my $i = {};
        #metadata
        my @keys = keys %$a;
        foreach my $key(@keys){
                #yaml configuratie in orde van prioriteit: exclude -> rename -> <niets veranderen> -> extra sorteerveld
                #exclude en rename sluiten elkaar uit!
                #yaml exclude
                if(defined($self->_yaml_index->{exclude}->{$key})){
                        next;
                }
                #yaml rename
                if(defined($self->_yaml_index->{rename}) && defined($self->_yaml_index->{rename}->{$key})){
                        $a->{$self->_yaml_index->{rename}->{$key}} = [];
			print "key => $key\n";
                        if(ref $a->{$key} eq "ARRAY"){
                                push @{$a->{$self->_yaml_index->{rename}->{$key}}},$_ foreach(@{$a->{$key}});
                        }elsif(ref $a->{$key} eq "HASH"){
                                push @{$a->{$self->_yaml_index->{rename}->{$key}}},$a->{$key}->{$_} foreach(keys %{$a->{$key}});
                        }else{
                                push @{$a->{$self->_yaml_index->{rename}->{$key}}},$a->{$key};
                        }
                        delete $a->{$key};
                        $key = $self->_yaml_index->{rename}->{$key};
                }
                #key
                $i->{$key} .= join(' ',$self->one_array($a->{$key}))." " if scalar(@{$a->{$key}} > 0);
                #to int?
                $i->{$key} = int($i->{$key}) if defined($self->_yaml_index->{type}) && defined($self->_yaml_index->{type}->{$key}) && $self->_yaml_index->{type}->{$key} eq "int";
                #sort
                $i->{$self->_yaml_index->{sort}->{$key}} = $self->clean($i->{$key}) if defined($self->_yaml_index->{sort}->{$key});
        }
        #media
        my @files = ();
        my $contexts = Set::Object::set();
        my $content_types = Set::Object::set();
        foreach my $item(@{$b->{media}}){
                $contexts->insert($item->{context});
                foreach my $file(@{$item->{file}}){
                        $content_types->insert($file->{content_type});
			next if !defined($file->{path});
                        my $f = basename($file->{path});
                        $f =~ s/\.\w+$//i;
                        push @files,$f;
                }
                foreach my $svc_id(keys %{$item->{devs}}){
                        $content_types->insert($item->{devs}->{$svc_id}->{content_type});
                }
        }
	$i->{files} = join(' ',@files);
        $i->{context}=join(' ',$contexts->elements);
        $i->{content_type}=join(' ',$content_types->elements);
        #verwijder alles dat leeg of undefined is
        foreach my $key(keys %$i){
                $i->{$key} =~ s/\s\s+/ /g;
                $i->{$key} =~ s/^\s//;
                $i->{$key} =~ s/\s$//;
                delete $i->{$key} if not defined($i->{$key}) or $i->{$key} eq "";
        }
        return $i;
}

1;

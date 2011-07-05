package Catmandu::Cmd::Command::updatemeta;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

#eigen module
use Catmandu::Store::Simple;
use Catmandu::Index::Solr;
use Set::Object;
use utf8;
use Text::Unaccent::PurePerl;
use Encode;
use YAML;
use Try::Tiny;

has temp => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'i',
    documentation => "Temporary meta database [required]",
    required => 1
);

has metadata => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'o',
    documentation => "Destination metadata database [required]",
    required => 1
);
has media => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'm',
    documentation => "Media database to check for files [required]",
    required => 1
);
has index => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'HashRef',
        cmd_aliases => 'I',
        documentation => "Parameters for the indexer (defaults to {url => http://localhost:8983/solr,id_field=>'id'})",
        default => sub{
                return {url => 'http://localhost:8983/solr',id_field=>'id'};
        }
);
has yaml => (
        traits => ['Getopt'],
        is => 'rw',
        isa => 'Str',
        cmd_aliases => 'y',
        documentation => "Configuration file, written in YAML"
);
has _yaml => (
        is =>'ro',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                my $hash;
                try{
                        $hash = YAML::LoadFile($self->yaml or "../yaml/aleph.yml");
                }catch{
                        print $_;
                        $hash = {};
                };
                $hash;
        }
);
has _temp => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->temp}) or die("could not open temporary meta database");
        }
);
has _metadata => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->metadata}) or die("could not open metadata database");
        }
);
has _media => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Store::Simple->new(%{$self->media}) or die("could not open media database");
        }
);

has _index => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                my $self = shift;
                Catmandu::Index::Solr->new(%{$self->index});
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
        encode("utf8", unac_string($oct));
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
sub update_index {
	my($self,$a,$b)=@_;
	my $i = {};
	#metadata
	my @keys = keys %$a;
        foreach my $key(@keys){
		#yaml configuratie in orde van prioriteit: exclude -> rename -> <niets veranderen> -> extra sorteerveld
		#exclude en rename sluiten elkaar uit!
		#yaml exclude
		if(defined($self->_yaml->{exclude}->{$key})){
                        next;
                }
		#yaml rename
		if(defined($self->_yaml->{rename}) && defined($self->_yaml->{rename}->{$key})){
                        $a->{$self->_yaml->{rename}->{$key}} = [];
                        if(ref $a->{$key} eq "ARRAY"){
                                push @{$a->{$self->_yaml->{rename}->{$key}}},$_ foreach(@{$a->{$key}});
                        }elsif(ref $a->{$key} eq "HASH"){
                                push @{$a->{$self->_yaml->{rename}->{$key}}},$a->{$key}->{$_} foreach(keys %{$a->{$key}});
                        }else{
                                push @{$a->{$self->_yaml->{rename}->{$key}}},$a->{$key};
                        }
                        delete $a->{$key};
                        $key = $self->_yaml->{rename}->{$key};
                }
		#key
		$i->{$key} .= join(' ',$self->one_array($a->{$key}))." " if scalar(@{$a->{$key}} > 0);
		#to int
		$i->{$key} = int($i->{$key}) if defined($self->_yaml->{type}) && defined($self->_yaml->{type}->{$key}) && $self->_yaml->{type}->{$key} eq "int";
		#sort
		$i->{$self->_yaml->{sort}->{$key}} = $self->clean($i->{$key}) if defined($self->_yaml->{sort}->{$key});
        }
	#media
	my @files = ();
	my $contexts = Set::Object::set();
        my $content_types = Set::Object::set();
        foreach my $item(@{$b->{media}}){
                $contexts->insert($item->{context});
                foreach my $file(@{$item->{file}}){
                        $content_types->insert($file->{content_type});
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
                $i->{$key} =~ s/\s\s+//g;
                $i->{$key} =~ s/^\s//;
                $i->{$key} =~ s/\s$//;
                delete $i->{$key} if not defined($i->{$key}) or $i->{$key} eq "";
        }
        $self->_index->save($i);	
	print " to index [OK]";
}
sub execute{
        my($self,$opts,$args)=@_;
	my $i = 0;
	$self->_temp->each(sub{
		$i++;
		my $newmetarecord = shift;
		#komt het voor in de merge?
		my $oldmetarecord = $self->_metadata->load($newmetarecord->{_id});
		my $mediarecord = $self->_media->load($newmetarecord->{_id});
		if(defined($oldmetarecord) && defined($mediarecord)){
			print $newmetarecord->{_id}."\n";
			$self->_metadata->save($newmetarecord);
			$self->update_index($newmetarecord,$mediarecord);
		}else{
			print STDERR $newmetarecord->{_id}." -> not in merge\n";
		}
	});
	print "$i records updated\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

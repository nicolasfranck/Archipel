package Catmandu::Cmd::Command::indexmerge;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

use Catmandu::Index::Solr;
use Catmandu::Store::Simple;
use Set::Object;
use utf8;
use Text::Unaccent::PurePerl;
use Encode;
use YAML;
use Try::Tiny;
use Array::Diff;
use File::Basename;

has dba => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'a',
    documentation => "Metadata database (a) [required]",
    required => 1
);

has dbb => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'HashRef',
    cmd_aliases => 'b',
    documentation => "Media database (b) [required]",
    required => 1
);

has index => (
	traits => ['Getopt'],
	is => 'rw',
	isa => 'HashRef',
	cmd_aliases => 'i',
	documentation => "Parameters for the indexer (defaults to {url => http://localhost:8983/solr,id_field=>'id'})",
	default => sub{
		return {url => 'http://localhost:8983/solr',id_field=>'id'};
	}
);
has _dba => (
	is => 'rw',	
	isa => 'Ref',
	lazy => 1,
	default => sub{
		Catmandu::Store::Simple->new(%{shift->dba});
	}
);
has _dbb => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
                Catmandu::Store::Simple->new(%{shift->dbb});
        }
);
has skip => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Bool',
    cmd_aliases => 'skip',
    documentation => "Skip entries, when not present in both databases",
    required => 0,
    default => sub{0}
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
sub diff{
        my($self,$first,$second)=@_;
        my $diff = Array::Diff->diff([sort @$first],[sort @$second]);
        $diff->added,$diff->deleted;
}
sub equal{
	my $self = shift;
	my $stha = $self->_dba->_dbh->prepare('select id from objects') or croak($self->_dba->_dbh->{errstr});
	$stha->execute;
	my $sthb = $self->_dbb->_dbh->prepare('select id from objects') or croak ($self->_dbb->_dbh);
	$sthb->execute;
	my $a = $stha->fetchall_arrayref;
	my $b = $sthb->fetchall_arrayref;
	$a = [map {$_->[0]} @$a];
	$b = [map {$_->[0]} @$b];
	my($added,$deleted)=$self->diff($a,$b);
	return scalar(@$added) == 0 && scalar(@$deleted) == 0;
}

sub index_merge {
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
		#to int?
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
}
sub execute{
        my($self,$opts,$args)=@_;
	if(not $self->skip){
		die "both databases are not equal\n" if not $self->equal;
	}
	#verzamel tweelingen
	try{
		$self->_dba->each(sub{
			my $a = shift;
			print $a->{_id};
			my $b = $self->_dbb->load($a->{_id});
			if(defined($b) && defined($b->{media}) && scalar(@{$b->{media}} > 0)){
				$self->index_merge($a,$b);
			}else{
				print " has no media, skipping..\n";
				return;
			}
			print "\n";
		});
	}catch{
		print $_;
	};
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;

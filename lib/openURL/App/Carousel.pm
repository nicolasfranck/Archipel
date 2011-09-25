package openURL::App::Carousel;
use strict;
use Plack::Util;
use Catmandu;

sub new {
	my $class = shift;
	my $openURL = Catmandu->conf->{middleware}->{openURL}->{resolve};
        my @acls = ();
        foreach my $acl(@{$openURL->{acls}}){
                my $class = $acl->{class};
                my $args = $acl->{args};
                Plack::Util::load_class($class);
                push @acls,$class->new(%$args);
        }
	bless {
		acls => \@acls
	},$class;
}
sub acls {
	shift->{acls};
}
sub mapping {
	Catmandu->conf->{middleware}->{openURL}->{app}->{types}->{carousel}->{mapping};
}
sub handle{
	my($self,$opts,$record)=@_;
	my $rels = [];
	foreach my $item(@{$record->{media}}){
		my $allowed = 1;
		my $svc_id = $self->mapping->{$item->{context}};
		foreach my $acl(@{$self->acls}){
			if(!$acl->is_allowed($opts->{env},$record,$item->{item_id},$svc_id)){
				$allowed = 0;
				last;
			}
		}
		next if !$allowed;
		push @$rels,{
			thumbnail => $item->{devs}->{thumbnail},
			title => $item->{title},
			item_id => $item->{item_id},
			context => $item->{context}
		};
	}
	my $scrollto = $opts->{args}->{scrollto};
	$scrollto = defined($scrollto) && $scrollto ne "" ? int($scrollto):0;	
	return {
		id => $record->{_id},
		rels => $rels,
		rooturl => Catmandu->conf->{all}->{rooturl},
		openURL => Catmandu->conf->{middleware}->{openURL},
		scrollto => $scrollto
	},200,undef;
}

1;

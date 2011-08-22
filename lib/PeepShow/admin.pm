package PeepShow::admin;
use Catmandu::App;

use parent qw(PeepShow::App::Common);

use Plack::Util;
use Clone qw(clone);
use Hash::Merge::Simple qw(merge);
use List::MoreUtils qw(first_index);

any([qw(get post)],'',sub{
	my $self=shift;

	my $params = $self->request->parameters;
	my $action = $params->{action} || "";
	my $submit = $params->{submit};
	my $desc_maxchars = Catmandu->conf->{app}->{admin}->{desc}->{maxchars};
	my $title_maxchars = Catmandu->conf->{app}->{admin}->{title}->{maxchars};
	my $query = $params->{query};
	my $id = $params->{id};
	my $title = $params->{title};
        my $desc = $params->{desc};
        my $rft_id = $params->{rft_id};
        my $item_id = $params->{item_id};
        my $added = $params->{added} || time;
	my $id_a = $params->{id_a} // "";
	my $id_b = $params->{id_b} // "";
	my $language = $params->{language};
	my @errs = ();

	my $page_args = $self->page_args;
	my $args={};

	if($action eq "add"){
		#controle
		my $new;
		my $id;
		if(defined($submit)){
			my $errs = [];
			($new,$errs) = $self->check_params_new;
			if(scalar(@$errs)==0){
				my $n = $self->columns->save($new);
				$args->{msgs}=['toegevoegd!'];
				$new->{id}=$n->{_id};
                	}else{
				push @errs,@$errs;
			}
		}
		$args->{column} = $new;
		$args->{errs}=\@errs;	
		$page_args->{args} = {%{$page_args->{args}},%$args};
		$self->print_template($self->template('new_column'),$page_args);
	}elsif($action eq "edit"){
		my $edit_confirm = ($params->{edit_confirm} && $params->{edit_confirm} eq "1")? 1:0;
		if($edit_confirm){
			my($merge,$errs)=$self->check_params_edit;
			if(scalar(@$errs)==0){
				$self->columns->save($merge);
				$args->{msgs}=["record $id is aangepast"];
			}else{
				$args->{errs} = $errs;				
			}
	                $merge->{id}=$merge->{_id};
                        $args->{column}=$merge;
		}else{
			my $record;
			if(!defined($id)){
				push @errs,"gelieve id op te geven";
			}
			elsif(!defined($record = $self->columns->load($id))){
				push @errs,"id $id komt niet voor in de databank";
			}elsif((first_index {$_ eq $language} @{$self->languages}) == -1){
				push @errs,"taal $language wordt niet ondersteund";
			}
			if(scalar(@errs)==0){
				$record->{id}=$record->{_id};
				$args->{column}=$record;
			}else{
				$args->{errs}=\@errs;
			}
		}
		$page_args->{args} = {%{$page_args->{args}},%$args};
		$self->print_template($self->template('new_column'),$page_args);
	}elsif($action eq "remove"){
		my $record = $self->columns->load($id);
                if(!defined($record)){
                        push @errs,"id $id komt niet voor in de databank";
                }elsif(defined($params->{language})){
			if($language && defined($record->{title}->{$language})){
				delete $record->{title}->{$language};
				delete $record->{desc}->{$language};
			}
			$self->columns->delete($id) if(scalar(keys %{$record->{title}}) == 0);
			if(scalar(keys %{$record->{title}}) == 0){
				$self->columns->delete($id);
			}else{
				$self->columns->save($record);
			}
		}else{
			$self->columns->delete($id);
		}
		$args->{errs}=\@errs;
		$page_args->{args} = {%{$page_args->{args}},%$args};
		$self->print_columns($page_args);
	}elsif($action eq "switch"){
		my $a = $self->columns->load($id_a);
		my $b = $self->columns->load($id_b);
		if(!defined($a)){
			push @errs,"record $id_a bestaat niet";
		}
		if(!defined($b)){
                        push @errs,"record $id_b bestaat niet";
                }
		if(scalar(@errs)==0){
			my $temp = $a->{added};
			$a->{added} = $b->{added};
			$b->{added} = $temp;
			$self->columns->save($a);
			$self->columns->save($b);
			$args->{msgs}=["records $id_a en $id_b zijn omgewisseld!"];			
		}else{
			$args->{errs} = \@errs;
		}
		$page_args->{args} = {%{$page_args->{args}},%$args};
		$self->print_columns($page_args);
	}else{
		$page_args->{args} = {%{$page_args->{args}},%$args};
                $self->print_columns($page_args);
	}
});

sub columns{
        my $self = shift;
        $self->stash->{columns} ||=$self->load_columns;
}
sub load_columns {
	my $self = shift;
	my $class = Catmandu->conf->{database}->{columns}->{class};
        Plack::Util::load_class($class);
	my $args = Catmandu->conf->{database}->{columns}->{args};
	$class->new(%$args);
}
sub print_columns {
	my($self,$page_args)=@_;
	my $columns = [];
        $self->columns->each(sub{push @$columns,shift;});
	for(my $i = 0;$i<scalar(@$columns);$i++){
		$columns->[$i]->{id} = $columns->[$i]->{_id};
        }
	$columns = [sort {$a->{added} <=> $b->{added}} @$columns];
	$page_args->{args}->{columns}=$columns;
        $self->print_template($self->template('columns'),$page_args);
}
sub check_params_new {
	my $self = shift;	
	my @errs = ();
	my $new;
	my $params = $self->request->parameters;
        my $title = $params->{title};
        my $desc = $params->{desc};
        my $rft_id = $params->{rft_id};
        my $item_id = $params->{item_id};
	my $query = $params->{query};
	my $language = $params->{language} // Catmandu->conf->{language}->{default};
	if(!(defined($title) && $title ne "")){
		push @errs,'gelieve een titel op te geven';
	}elsif(length($title)> Catmandu->conf->{app}->{admin}->{title}->{maxchars}){
		push @errs,'maximum aantal karakters voor titel:'.Catmandu->conf->{app}->{admin}->{title}->{maxchars};
	}
	if(!(defined($desc) && $desc ne "")){
		push @errs,'gelieve een beschrijving op te geven';
	}elsif(length($desc) > Catmandu->conf->{app}->{admin}->{desc}->{maxchars}){
		push @errs,'maximum aantal karakters voor beschrijving:'.Catmandu->conf->{app}->{admin}->{desc}->{maxchars};
	}
	if(!(defined($rft_id) && $rft_id ne "")){
		push @errs,'gelieve een record-nummer op te geven';
	}
	if(!(defined($item_id) && $item_id ne "")){
		push @errs,'gelieve het nummer van het item op te geven';
	}
	if(!(defined($query) && $query ne "")){
		push @errs,'gelieve een zoekquery op te geven';
	}
	if((first_index {$_ eq $language} @{$self->languages}) == -1){
		push @errs,"taal $language wordt niet ondersteund";
	}
	if(scalar(@errs)==0){
		$new = $self->db->load($rft_id);
		my $dev;
		if(not defined($new)){
			push @errs,"record $rft_id komt niet voor in de databank";
		}elsif(not defined($new->{media}->[$item_id - 1])){
			push @errs,"item $item_id komt niet voor in record $rft_id";
		}else{
			$new = {
				title =>{$language=>$title},desc=>{$language=>$desc},rft_id=> $rft_id,
				item_id=>$item_id,query=>$query,added => time
			};
		}
	}
	return $new,\@errs;
}
sub check_params_edit {
	my $self = shift;
	my @errs = ();
	my $params = $self->request->parameters;
	my($new,$errs) = $self->check_params_new;
	delete $new->{added};
	@errs = @$errs;
	my $id = $params->{id};
	my $old;
	if(!defined($id) || $id eq ""){
		push @errs,"id $id is niet opgegeven";
	}
	elsif(!defined($old = $self->columns->load($id))){
		push @errs,"id $id bestaat niet";
	}
	return merge($old,$new),\@errs;
}
__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

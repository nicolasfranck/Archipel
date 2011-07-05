package PeepShow::admin;
use Catmandu::App;
use PeepShow::Resolver::DB;
use Plack::Util;
use Clone qw(clone);
use Data::UUID;
use Hash::Merge::Simple qw(merge);
use List::MoreUtils qw(first_index);

any([qw(get post)],'',sub{
	my $self=shift;

	my $params = $self->request->parameters;
	my $action = $params->{action} || "";
	my $submit = $params->{submit};
	my $desc_maxchars = $self->conf->{desc}->{maxchars};
	my $title_maxchars = $self->conf->{title}->{maxchars};
	my $query = $params->{query};
	my $id = $params->{id};#bij wijzigingen..
	my $title = $params->{title};
        my $desc = $params->{desc};
        my $rft_id = $params->{rft_id};
        my $item_id = $params->{item_id};
        my $added = $params->{added} || time;
	my $id_a = $params->{id_a} // "";
	my $id_b = $params->{id_b} // "";
	my $language = $params->{language};
	my @errs = ();
	my $page_args={rooturl=>$self->rooturl};
	if($action eq "add"){
		#controle
		my $new;
		my $id;
		if(defined($submit)){
			my $errs = [];
			($new,$errs) = $self->check_params_new;
			if(scalar(@$errs)==0){
				my $n = $self->columns->save($new);
				$page_args->{msgs}=['toegevoegd!'];
				$new->{id}=$n->{_id};
                	}else{
				push @errs,@$errs;
			}
		}
		$page_args->{column} = $new;
		$page_args->{errs}=\@errs;	
		$page_args->{params}=$params;
		$page_args->{conf}=$self->conf;
		$self->print_template('new_column',$page_args);
	}elsif($action eq "edit"){
		my $edit_confirm = ($params->{edit_confirm} && $params->{edit_confirm} eq "1")? 1:0;
		if($edit_confirm){
			my($merge,$errs)=$self->check_params_edit;
			if(scalar(@$errs)==0){
				$self->columns->save($merge);
				$page_args->{msgs}=["record $id is aangepast"];
			}else{
				$page_args->{errs} = $errs;				
			}
			$page_args->{conf}=$self->conf;
        	        $page_args->{params}=$params;
	                $merge->{id}=$merge->{_id};
                        $page_args->{column}=$merge;
			$self->print_template('new_column',$page_args);
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
				$page_args->{conf}=$self->conf;
				$page_args->{params}=$params;
				$record->{id}=$record->{_id};
				$page_args->{column}=$record;
				$self->print_template('new_column',$page_args);
			}else{
				$page_args->{errs}=\@errs;
				$page_args->{params}=$params;
				$page_args->{conf}=$self->conf;
				$self->print_columns($page_args);
			}
		}
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
		$page_args->{errs}=\@errs;
		$page_args->{params}=$params;
                $page_args->{conf}=$self->conf;
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
			$page_args->{msgs}=["records $id_a en $id_b zijn omgewisseld!"];			
		}else{
			$page_args->{errs} = \@errs;
		}
		$page_args->{conf}=$self->conf;
		$self->print_columns($page_args);
	}else{
		$page_args->{conf}=$self->conf;
		$self->print_columns($page_args);
	}
});

sub columns{
        my $self = shift;
        $self->stash->{store} ||=$self->_build_columns;
}
sub _build_columns {
	my $self = shift;
	my $class = $self->conf->{db}->{class};
        Plack::Util::load_class($class);
	$class->new($self->conf->{db}->{args});
}
sub db {
	my $self = shift;
	$self->stash->{db} ||= PeepShow::Resolver::DB->new();
}
sub conf {
	my $self = shift;
	my $c =	{%{Catmandu->conf->{Columns}},languages => Catmandu->conf->{languages}};
	return $c;
}
sub baseurl{
        my $self = shift;
        my $rooturl = $self->rooturl;
        my $own_path = $self->request->path;
        my $params = clone($self->request->parameters);
        delete $params->{language};
        delete $params->{view};
        my $url = "$rooturl$own_path?".join('&',map {$_."=".$params->{$_}} keys %{$params});
        return $url;
}
sub rooturl{
	Catmandu->conf->{rooturl};
}
sub openURL {
	Catmandu->conf->{openURL};
}
sub print_columns {
	my($self,$page_args)=@_;
	my $columns = [];
        $self->columns->each(sub{push @$columns,shift;});
	for(my $i = 0;$i<scalar(@$columns);$i++){
		$columns->[$i]->{id} = $columns->[$i]->{_id};
        }
	$columns = [sort {$a->{added} <=> $b->{added}} @$columns];
	$page_args->{columns}=$columns;
        $self->print_template('columns',$page_args);
}
sub languages {
	my $self = shift;
	Catmandu->conf->{languages};
}
sub check_params_new {
	my $self = shift;	
	my @errs = ();
	my $new;
	#parameters
	my $params = $self->request->parameters;
        my $title = $params->{title};
        my $desc = $params->{desc};
        my $rft_id = $params->{rft_id};
        my $item_id = $params->{item_id};
	my $query = $params->{query};
	my $language = $params->{language} // $self->languages->[0];
	if(!defined($title) || $title eq ""){
		push @errs,'gelieve een titel op te geven';
	}elsif(length($title)> $self->conf->{title}->{maxchars}){
		push @errs,'maximum aantal karakters voor titel:'.$self->conf->{title}->{maxchars};
	}
	if(!defined($desc) || $desc eq ""){
		push @errs,'gelieve een beschrijving op te geven';
	}elsif(length($desc) > $self->conf->{desc}->{maxchars}){
		push @errs,'maximum aantal karakters voor beschrijving:'.$self->conf->{desc}->{maxchars};
	}
	if(!defined($rft_id) || $rft_id eq ""){
		push @errs,'gelieve een record-nummer op te geven';
	}
	if(!defined($item_id) || $item_id eq ""){
		push @errs,'gelieve het nummer van het item op te geven';
	}
	if(!defined($query) || $query eq ""){
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

package PeepShow::mycart;
use Catmandu::App;

use parent qw(PeepShow::App::Common);

use PeepShow::Tools::Record;
use Data::Pageset;
use JSON;
use MIME::Lite::TT::HTML;
use Email::Valid;

any([qw(get post)],'',sub{

	my $self = shift;

	#sessie
	my $sess = $self->request->session;		
	#parameters
	my $params = $self->request->parameters;
	my $pages_per_set = 10;
	my $num = (defined($params->{num}))? $params->{num}:12;	
	my $page = ($params->{page} && $params->{page} > 0 && $params->{page} =~ /^\d+$/)? $params->{page} : 1;	
	my $offset = ($page - 1)*$num;		
	#mailen
	my $mailconfirm = $params->{mailconfirm} || 0; 
	my $from = $params->{from};
	my $to = $params->{to};
	my $realfrom = Catmandu->conf->{app}->{cart}->{email}->{realfrom};#werkelijk email-adres van waaruit wordt gestuurd
	my $message = $params->{message};
	my $captcha_html;
	#(fout)boodschappen
	my @messages = ();
	my @errors = ();

	#acties
	my $action = $params->{action};
	my $id = $params->{id};
	my $newid;
	if(defined($action) && $action ne ""){
		if($action eq "clear"){
			$sess->{devs} = {};
		}	
		elsif($action eq "remove" && defined($id) && $id ne ""){
			delete $sess->{devs}->{$id} if defined($sess->{devs}->{$id});
		}
		elsif($action eq "load" && defined($id) && $id ne ""){
			my $temp = $self->snapshots->load($id) || {};
			$sess->{devs} = $temp->{devs};
		}elsif($action eq "mail"){
			$captcha_html = $self->captcha->get_html(Catmandu->conf->{all}->{captcha}->{public_key});
			if(defined($mailconfirm) && $mailconfirm eq "1"){
				my($success,$errors) = $self->validate_captcha($params);
				push @errors,@$errors if !$success;
				push @errors,{err=>1,errmsg=>"SENDMAIL_REALFROM_NOT_VALID"} if !Email::Valid->address($realfrom);
				push @errors,{err=>1,errmsg=>"SENDMAIL_FROM_NOT_VALID"} if !Email::Valid->address($from);
				push @errors,{err=>1,errmsg=>"SENDMAIL_TO_NOT_VALID"} if !Email::Valid->address($to);
				
				if(scalar(@errors)==0){
					if(defined($sess->{devs}) && scalar(keys %{$sess->{devs}}) > 0){
						#opslaan voor later gebruik..
						$newid = Data::UUID->new->create_str();
						$self->snapshots->save({_id=>$newid,timestamp=>time,devs=>$sess->{devs}});
						#..en een link opsturen naar kameraad voor deze snapshot
						my $mime = MIME::Lite::TT::HTML->new(
							From => $realfrom,
							To => $to,
							Subject => "beeldmateriaal peepshow",
							Template => {
								html => $self->template('sendmail_mycart')
							},
							Charset     => 'utf8',
							TmplOptions => {INCLUDE_PATH=>Catmandu->home."/template"},
							TmplParams  =>  {from=>$from,to=>$to,link=>Catmandu->conf->{all}->{rooturl}."/mycart?action=load&id=$newid",message=>$message}
						);
						my $success = $mime->send(@{Catmandu->conf->{app}->{cart}->{email}->{params}});
						if(not $success){
							push @errors,{err=>1,errmsg=>'SENDMAIL_FAILED',from=>$realfrom,to=>$to};
						}else{
							push @messages,{success=>1,msg=>'SENDMAIL_SUCCESS',from=>$realfrom,to=>$to};
						}
					}
				}else{
					$mailconfirm = 1
				}
			}else{
				$mailconfirm = 1;	
			}
		}
	}

	#overzicht geselecteerde records (met aangeven van hoeveel items daarin geselecteerd zijn)
	my $total_records = scalar keys %{$sess->{devs}};
	if($total_records > 0){			
		my $temp = [
			sort {$a->{added} <=> $b->{added}}
			map {
				my $obj = {
					rft_id => $_,
					poster_item_id => $sess->{devs}->{$_}->{poster_item_id},
					added => $sess->{devs}->{$_}->{added},
					title => $sess->{devs}->{$_}->{title},
					marked => $sess->{devs}->{$_}->{marked},
					numitems => $sess->{devs}->{$_}->{numitems},
					posterwidth => $sess->{devs}->{$_}->{posterwidth},
					posterheight => $sess->{devs}->{$_}->{posterheight}
				};
			}
			sort keys %{$sess->{devs}}
		];			
		my $records = slice($temp,$offset,$num);	
		my $page_info = Data::Pageset->new({
			'total_entries'       => $total_records || 0,
			'entries_per_page'    => $num,
			'current_page'        => $page,
			'pages_per_set'       => $pages_per_set || 0,
			'mode'                => 'fixed'
		});

		my $args = {
                        num => $num,
                        total_entries => $total_records,
                        begin_item => $offset+1,
                        end_item => $offset+scalar(@$records),
                        first_page => $page_info->first_page,
                        last_page => $page_info->last_page,
                        previous_page => $page_info->previous_page,
                        next_page => $page_info->next_page,
                        pages_in_set => $page_info->pages_in_set,
                        current_page => $page_info->current_page,
                        records => $records,
                        messages=>\@messages,
                        errors=>\@errors,
			mailconfirm => $mailconfirm,
			captcha_html => $captcha_html
                };
		my $page_args = $self->page_args;
		$page_args->{args} = {%{$page_args->{args}},%$args};
		$self->print_template($self->template('mycart'),$page_args);	
		
	}else{
		my $page_args = $self->page_args;
		my $args = {errmsg=>"geen records aanwezig in mandje"};
		$page_args->{args} = {%{$page_args->{args}},%$args};
		$self->print_template($self->template('mycart'),$page_args);
	}
});

sub snapshots {
	my $self = shift;
	$self->stash->{dbcarts} ||= $self->load_snapshots;
}
sub load_snapshots {
	my $self = shift;
	my $class = Catmandu->conf->{database}->{cart}->{class};
	Plack::Util::load_class($class);
	$class->new(%{Catmandu->conf->{database}->{cart}->{args}});
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

package PeepShow::App::Common;
use utf8;
use Catmandu::App;
use Captcha::reCAPTCHA;
use Try::Tiny;

sub db{
	$_[0]->stash->{db} ||= PeepShow::Resolver::DB->new();
}
sub tag_index {
        $_[0]->stash->{tags} ||= Plack::Util::load_class(Catmandu->conf->{index}->{tags}->{class})->new(%{Catmandu->conf->{index}->{tags}->{args}});
}
sub source_ip {
        my $self = shift;
        my $source_ip = $self->env->{HTTP_X_FORWARDED_FOR} ? $self->env->{HTTP_X_FORWARDED_FOR} : $self->env->{REMOTE_ADDR};
        my @ips = split(',',$source_ip);
        $source_ip = pop @ips;
        return $source_ip;
}
sub languages {
        [grep {$_ ne "default"} keys %{Catmandu->conf->{language}}];
}
sub validate_captcha {
	my($self,$params) = @_;
	my $success = 0;
	my @errors = ();
	my $public_key = Catmandu->conf->{all}->{captcha}->{public_key};
        my $private_key = Catmandu->conf->{all}->{captcha}->{private_key};
	my $result = $self->captcha->check_answer(
                $private_key,
                $self->env->{REMOTE_ADDR},
                $params->{recaptcha_challenge_field},
                $params->{recaptcha_response_field}
        );      
        $success = $result->{is_valid};
        push @errors,$result->{error} if !$success;
	return $success,\@errors;
}
sub captcha_html {
	$_[0]->captcha->get_html(Catmandu->conf->{all}->{captcha}->{public_key});
}
sub captcha {
	$_[0]->stash->{captcha} ||= Captcha::reCAPTCHA->new;
}
sub page_args {
	my $self = shift;
	return {
		conf => Catmandu->conf,
		env => $self->env,
		params => $self->request->parameters,
		sess => $self->request->session,
		app => {languages=>$self->languages},
		args=>{language=>$self->language}
	};
}
sub template{
        my($self,$template) = @_;
        Catmandu->conf->{templates}->{$template};
}
sub language{
        my $self = shift;
        my $language = $self->request->parameters->{language};
        $language = (defined($language) && defined(Catmandu->conf->{language}->{$language}))? $language:Catmandu->conf->{language}->{default};
}

__PACKAGE__->meta->make_immutable;
no Catmandu::App;
__PACKAGE__;

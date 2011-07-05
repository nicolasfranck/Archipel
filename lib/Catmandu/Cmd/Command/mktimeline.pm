package Catmandu::Cmd::Command::mktimeline;
our $VERSION = 0.01;# VERSION
#nodig voor cmd::command
use Moose;
use Catmandu;
use Plack::Runner;
use Plack::Util;

extends qw(Catmandu::Cmd::Command);

use Catmandu::Index::Solr;
use Catmandu::Store::Merge;
use DBI;
use Try::Tiny;
use utf8;

has dba => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'a',
    documentation => "Metadata database (a) [required]",
    required => 1
);
has dbb => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 'b',
    documentation => "Media database (a) [required]",
    required => 1
);
has dbt => (
    traits => ['Getopt'],
    is => 'rw',
    isa => 'Str',
    cmd_aliases => 't',
    documentation => "Timeline database to create [required]",
    required => 1
);

has _merge => (
	is => 'rw',	
	isa => 'Ref',
	lazy => 1,
	default => sub{
		my $self = shift;
		Catmandu::Store::Merge->new(patha=>$self->dba,pathb=>$self->dbb);
	}
);
has _dbh => (
        is => 'rw',
        isa => 'Ref',
        lazy => 1,
        default => sub{
		my $self = shift;
		my $SQL_CREATE_TABLE = "CREATE TABLE IF NOT EXISTS timeline(rft_id varchar(6) PRIMARY KEY,item_id int not null,year int not null)";
		my $path = $self->dbt;
		my $dbh = DBI->connect("dbi:SQLite:dbname=$path", "", "");
		$dbh->{sqlite_unicode} = 1;
		#$dbh->{AutoCommit} = 0;
		$dbh->{RaiseError} = 1;
		$dbh->do($SQL_CREATE_TABLE) or confess $dbh->errstr;
		$dbh;
        }
);

sub execute{
        my($self,$opts,$args)=@_;
	my $query = "insert into timeline(rft_id,year,item_id)values(?,?,?)";
	my $sth = $self->_dbh->prepare($query);
	my $dbh = $self->_dbh;
	try{
		$dbh->begin_work;
		my $val = $self->_merge->each(sub{
			my $r = shift;
			print $r->{_id}."\n";
	                return if not(defined($r->{media}) && scalar(@{$r->{media}}) > 0);
			$sth->execute($r->{_id},$r->{year}->[0],int($r->{poster_item_id}));
		});
		$dbh->commit;
	}catch{
		$dbh->rollback;
		confess $_;
	}finally{
		$dbh->disconnect;
	};
}

__PACKAGE__->meta->make_immutable;
no Moose;
__PACKAGE__;
# fetch: select distinct t1.year,(select t2.rft_id from timeline as t2 where t2.year = t1.year limit 1) from timeline as t1

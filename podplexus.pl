#!/usr/bin/env perl

use warnings;
use strict;

{
	package Document;

	use Moose;
	use PPI;
	use Pod::Elemental;

	use PPI::Lexer;
	$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';

	has pathname => ( is => 'ro', isa => 'Str', required => 1 );

	has library => (
		is       => 'ro',
		isa      => 'Library',
		required => 1,
		weak_ref => 1,
	);

	has ppi => (
		is      => 'ro',
		isa     => 'PPI::Document',
		lazy    => 1,
		default => sub { PPI::Document->new( shift()->pathname() ) },
	);

	has elemental => (
		is      => 'ro',
		isa     => 'Pod::Elemental::Document',
		lazy    => 1,
		default => sub { Pod::Elemental->read_file( shift()->pathname() ) },
	);

	has template => (
		is       => 'ro',
		isa      => 'Template',
		required => 1,
	);

	### Public accessors!

	has module => (
		is      => 'ro',
		isa     => 'Str',
		lazy    => 1,
		default => sub {
			my $self = shift();

			my $main_package = $self->ppi()->find_first('PPI::Statement::Package');
			return "" unless $main_package;

			return $main_package->namespace();
		},
	);

	has abstract => (
		is      => 'ro',
		isa     => 'Str',
		lazy    => 1,
		default => sub {
			my $self = shift();

			use Pod::Elemental::Selectors qw(s_command);

			my $children = $self->elemental()->children();
			my $commands = s_command('abstract');

			my @abstract_index;

			for my $i (0 .. $#$children) {
				next unless $commands->( $children->[$i] );
				push @abstract_index, $i;
			}

			die $self->module(), " has no abstract" unless @abstract_index;
			die $self->module(), " has too many abstracts" if @abstract_index > 1;

			# Remove it.
			my $abstract = splice( @$children, $abstract_index[0], 1 );

			return $abstract->content();
		},
	);

	sub code {
		my $self = shift();

		my $out = $self->ppi()->clone();
		$out->prune('PPI::Statement::End');
		$out->prune('PPI::Statement::Data');
		$out->prune('PPI::Token::Pod');

		return $out->serialize();
	}

	sub sub {
		my ($self, $sub_name) = @_;

		my $subs = $self->ppi()->find(
			sub {
				$_[1]->isa('PPI::Statement::Sub') and
				defined($_[1]->name()) and
				$_[1]->name() eq $sub_name
			}
		);

		die $self->module(), " doesn't define sub $sub_name" unless @$subs;
		die $self->module(), " defines too many subs $sub_name" if @$subs > 1;

		return $subs->[0]->content();
	}

	### End public accessors!

	sub BUILD {
		warn "Absorbing ", shift()->pathname(), " ...\n";
	}

	sub render {
		my $self = shift();

		my $elemental = $self->elemental();

		# TODO - I can see why autoboxing is sexy.

		my $input = "";
		my @queue = @{$self->elemental()->children()};
		while (@queue) {
			my $next = shift @queue;
			$input .= $next->as_pod_string();

			next unless $next->can("children");
			my $sub_children = $next->children();
			unshift @queue, @$sub_children if @$sub_children;
		}

		my $output = "";

		my %vars = (
			doc => $self,
			lib => $self->library(),
		);

		$self->template()->process(\$input, \%vars, \$output) or die(
			$self->template()->error()
		);

		return $output;
	}

	sub ppidump {
		my $self = shift();
		use PPI::Dumper;
		my $d = PPI::Dumper->new( $self->ppi() );
		$d->print();
		exit;
	}

	no Moose;
}

{
	package Library;

	use Moose;
	use File::Find;
	use Carp qw(confess);

	has documents => (
		is      => 'rw',
		isa     => 'HashRef[Document]',
		default => sub { { } },
		traits  => [ 'Hash' ],
		handles => {
			has_document => 'exists',
			add_document => 'set',
			get_document => 'get',
		},
	);

	has modules => (
		is      => 'rw',
		isa     => 'HashRef[Document]',
		default => sub { { } },
		traits  => [ 'Hash' ],
		handles => {
			has_module => 'exists',
			add_module => 'set',
			get_module => 'get',
		},
	);

	has template => (
		is      => 'ro',
		isa     => 'Template',
		lazy    => 1,
		default => sub { Template->new() },
	);

	sub module {
		my ($self, $module) = @_;

		confess "module $module doesn't exist" unless $self->has_module($module);
		return $self->get_module($module);
	}

	sub add_files {
		my ($self, $filter, @roots) = @_;

		find(
			{
				wanted => sub {
					return if $self->has_document($_) or not $filter->($_);

					my $document = Document->new(
						pathname => $_,
						library  => $self,
						template => $self->template(),
					);

					$self->add_document($_ => $document);
					$self->add_module($document->module() => $document);
				},
				no_chdir => 1,
			},
			@roots,
		);
	}

	no Moose;
}

### Main.

use File::Find;
use Template;

my $lib = Library->new();

$lib->add_files(
	sub { my $path = shift(); (-f $path) && ($path =~ /\.pm$/) },
	"lib"
);

my $doc = $lib->get_document("lib/App/PipeFilter/Generic.pm");
#$doc->ppidump();
print $doc->render(), "\n";


__END__

-r--r--r--  1 root  admin  1018 Aug 24  2010 Autoblank.pm
-r--r--r--  1 root  admin   815 Aug 24  2010 Autochomp.pm
-r--r--r--  1 root  admin  1409 Aug 24  2010 Command.pm
-r--r--r--  1 root  admin  2966 Aug 24  2010 Document.pm
drwxr-xr-x  5 root  admin   170 May 21 20:36 Element/
-r--r--r--  1 root  admin  1072 Aug 24  2010 Flat.pm
-r--r--r--  1 root  admin  1584 Aug 24  2010 Node.pm
-r--r--r--  1 root  admin  2350 Aug 24  2010 Objectifier.pm
-r--r--r--  1 root  admin  2283 Aug 24  2010 Paragraph.pm
-r--r--r--  1 root  admin  3218 Nov 29  2009 PerlMunger.pm
-r--r--r--  1 root  admin  3533 Aug 24  2010 Selectors.pm
drwxr-xr-x  5 root  admin   170 May 21 20:36 Transformer/
-r--r--r--  1 root  admin  1179 Aug 24  2010 Transformer.pm
-r--r--r--  1 root  admin  1252 Aug 24  2010 Types.pm




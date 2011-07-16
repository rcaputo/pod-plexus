package Pod::Plexus::Library;

use Moose;
use File::Find;
use Template;
use Carp qw(confess);

use Pod::Plexus::Document;

has documents => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Document]',
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
	isa     => 'HashRef[Pod::Plexus::Document]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		has_module => 'exists',
		add_module => 'set',
		get_module => 'get',
		get_module_names => 'keys',
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

				$self->add_file($_);
			},
			no_chdir => 1,
		},
		@roots,
	);
}

sub add_file {
	my ($self, $file_path) = @_;

	my $document = Pod::Plexus::Document->new(
		pathname => $file_path,
		library  => $self,
		template => $self->template(),
	);

	$document->collect_data();

	$self->add_document($file_path => $document);
	$self->add_module($document->module() => $document);

	undef;
}

no Moose;

1;

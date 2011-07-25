package Pod::Plexus::Cli;

use Moose;
with 'MooseX::Getopt';

use Pod::Plexus::Library;
use File::Find;

has lib => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	required      => 1,
	default       => sub { [ 'lib' ] },
	documentation => 'one or more library root directories (default: lib)',
);

has module => (
	is            => 'rw',
	isa           => 'ArrayRef[Str]',
	lazy          => 1,
	default       => sub { [ ] },
	documentation => 'modules to render docs for (default: all found)',
);

has podroot => (
	is            => 'rw',
	isa           => 'Str',
	lazy          => 1,
	default       => '-',
	documentation => 'root directory where POD files are rendered',
);

has _library => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Library',
	default => sub { Pod::Plexus::Library->new() },
);

sub is_indexable_file {
	my ($self, $qualified_path) = @_;
	return unless $qualified_path =~ /\.pm$/;
	return 1;
}

sub collect_files {
	my $self = shift();

	find(
		{
			wanted => sub {
				return unless -f $_;
				return unless $self->is_indexable_file($_);
				return if $self->_library()->has_file($_);

				$self->_library()->add_file($_);
			},
			no_chdir => 1,
		},
		@{$self->lib()},
	);

	return 0;
}

sub index_library {
	my $self = shift();
	$self->_library()->index();
	return 0;
}

sub dereference_library {
	my $self = shift();
	$self->_library()->dereference();
	return 0;
}

sub render_library {
	my $self = shift();
	warn "render_library()... not yet";  # TODO
	return 0;
}

sub run {
	my $self = shift();

	return(
		$self->collect_files()       ||
		$self->index_library()       ||
		$self->dereference_library() ||
		$self->render_library()      ||
		0
	);
}

no Moose;

1;

__END__

=abstract The Pod::Plexus command line utility implementation.

=cut

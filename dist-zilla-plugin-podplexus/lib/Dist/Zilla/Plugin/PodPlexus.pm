package Dist::Zilla::Plugin::PodPlexus;

use Moose;
with qw(
	Dist::Zilla::Role::FileMunger
);

use Moose::Autobox;
use Pod::Plexus::Library;

has library => (
	default => sub { Pod::Plexus::Library->new() },
	is      => 'rw',
	isa     => 'Pod::Plexus::Library',
	lazy    => 1,
);

sub munge_files {
	my $self = shift();

	# Index all files.  Done as a single pass before actual munging
	# since we don't know which files need which index information.

	foreach my $file ($self->zilla()->files()->flatten()) {

		# We only want things that include POD.
		# TODO - Is there a better way?
		next unless $file->name() =~ /^(?:bin|lib)\//;

		$self->library()->add_file($file->name());
	}

	# Munge each file individually.

	my $documents = $self->library()->documents();
	foreach my $file ($self->zilla()->files()->flatten()) {
		my $path = $file->name();

		next unless exists $documents->{$path};

		my $doc = $documents->{$path};

		$doc->collect_ancestry();
		$doc->expand_commands();

		$file->content( $doc->render() );
	}
}

no Moose;
1;

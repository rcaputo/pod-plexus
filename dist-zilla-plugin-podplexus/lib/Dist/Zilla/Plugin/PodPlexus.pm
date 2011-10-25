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

	# We only want things that include POD.
	# TODO - Is there a better way?
	# TODO - Also... MANIFEST.SKIP anyone?

	my @qualifying_files = (
		grep { $_->name() !~ /~$/ }
		grep { $_->name() =~ /^lib\// }
		$self->zilla()->files()->flatten()
	);

	$self->library()->add_file($_->name()) foreach @qualifying_files;

	my $documents = $self->library()->files();
	my @errors;

	foreach my $file (@qualifying_files) {
		my $path = $file->name();

		unless (exists $documents->{$path}) {
			warn "Why isn't $path in the library";
			next;
		}

		my $doc = $documents->{$path};
		$doc->prepare_to_render(\@errors);

		if (@errors) {
			warn "$_\n" foreach @errors;
			exit 1;
		}
	}

	# Render documentation.

	foreach my $file (@qualifying_files) {
		my $path = $file->name();

		next unless exists $documents->{$path};

		my $doc = $documents->{$path};
		$file->content( $doc->render_as_pod() );
	}
}

no Moose;
1;

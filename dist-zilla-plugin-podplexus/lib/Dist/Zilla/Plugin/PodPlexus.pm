package Dist::Zilla::Plugin::PodPlexus;

use Moose;
with qw(
	Dist::Zilla::Role::FileMunger
);

use Moose::Autobox;
use Pod::Plexus::Distribution;

has distribution => (
	default => sub { Pod::Plexus::Distribution->new() },
	is      => 'rw',
	isa     => 'Pod::Plexus::Distribution',
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

	my $distribution = $self->distribution();

	$distribution->add_file($_->name()) foreach @qualifying_files;

	my @errors;

	PREPARE: foreach my $file (@qualifying_files) {
		my $path = $file->name();

		my $module = $distribution->get_module($path);
		unless ($module) {
			warn "Why isn't $path in the distribution";
			next PREPARE;
		}

		my @errors = $module->cache_structure();
		if (@errors) {
			warn "$_\n" foreach @errors;
			exit 1;
		}
	}

	# Render documentation.

	RENDER: foreach my $file (@qualifying_files) {
		my $path = $file->name();

		my $module = $distribution->get_module($path);
		unless ($module) {
			warn "Why isn't $path in the distribution";
			next RENDER;
		}

		$file->content( $module->render_as_pod() );
	}
}

no Moose;
1;

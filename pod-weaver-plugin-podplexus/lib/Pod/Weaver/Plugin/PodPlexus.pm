package Pod::Weaver::Plugin::PodPlexus;

use Moose;
with qw(
	Pod::Weaver::Role::Preparer
	Pod::Weaver::Role::Dialect
);

use Pod::Plexus::Library;

has library => (
	is      => 'rw',
	isa     => 'Pod::Plexus::Library',
);

has this_file => ( is => 'rw', isa => 'Str' );

sub prepare_input {
	my ($self, $input) = @_;

	# TODO - As of this writing, each file gets its own instance of the
	# plugin, so an object-scoped library() doesn't work.  You can see
	# "$self" below change each time prepare_input() is called.
	#
	# From looking at Pod::Weaver's weave_document(), it appears that
	# prepare_input() and translate_dialect() are called in sequence for
	# every file to be woven.
	#
	# I had wanted to save $input->{filename} here so it would be
	# visible to translate_dialect() below.  Then translate_dialect()
	# could look up the Pod::Plexus document corresponding to the file
	# being woven.
	#
	# However this kind of sucks for at least two reasons.  First, we
	# can't initialize library() once and reuse it.  Second, it relies
	# on undocumented timing in Pod::Weaver's weave_document().

	warn $self, " = ",  # TODO - For debugging.
	$self->this_file($input->{filename});

	# Only set up the library once.

	return if $self->library();

	# We only want things that include POD.
	# TODO - There should be a better way.

	my @pod_files = (
		grep { $_->name() =~ /^(?:bin|lib)\// }
		@{ $input->{zilla}->files() }
	);

	$self->library( Pod::Plexus::Library->new() );
	$self->library()->add_file($_->name()) foreach @pod_files;
}

sub translate_dialect {
	my ($self, $elemental_doc) = @_;

	warn "  ", $self->this_file();
return;
	# TODO - How do I tell which document in my library this is?

	#my $pod_plexus_doc = $self->library()->
	#warn "@_";
exit;
	# Munge each file individually.

#	my $documents = $self->library()->documents();
#	foreach my $file ($self->zilla()->files()->flatten()) {
#		my $path = $file->name();
#
#		next unless exists $documents->{$path};
#
#		my $doc = $documents->{$path};
#
#		$doc->collect_ancestry();
#		$doc->expand_commands();
#
#		$file->content( $doc->render() );
#	}
#}
#	warn $input->{zilla};
#	warn $self->zilla();

	exit;

	#return if defined $self->library();
}

no Moose;
1;

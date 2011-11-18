package Pod::Plexus::Module;

=abstract Represent and render a single module in a distribution.

=cut

use Moose;
use Pod::Plexus::Module::Code;
use Pod::Plexus::Module::Docs;


has docs => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Module::Docs',
	lazy    => 1,
	default => sub {
		my $self = shift();
		Pod::Plexus::Module::Docs->new(
			module  => $self,
			verbose => $self->verbose(),
		);
	},
	handles => {
		abstract        => 'abstract',
		render_as_pod   => 'render_as_pod',
		get_docs_matter => 'get_matter',
		skips_attribute => 'skips_attribute',
		skips_method    => 'skips_method',
	},
);


has code => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Module::Code',
	lazy    => 1,
	default => sub {
		my $self = shift();
		Pod::Plexus::Module::Code->new(
			module  => $self,
			verbose => $self->verbose(),
		);
	},
	handles => {
		package            => 'package',
		get_sub_code       => 'get_sub',
		get_module_code    => 'get_module',
		get_attribute_code => 'get_attribute',
		register_matter    => 'register_matter',
		get_meta_class     => 'meta_entity',
	},
);


has verbose => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=attribute pathname

[% s.name %] contains the relative path and name of the file being
documented.

=cut

has pathname => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute distribution

[% s.name %] contains the Pod::Plexus::Distribution object that
represents the entire distribution of modules.  It allows the current
module to access its sibling modules through the distribution
containing them.

=cut

has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	required => 1,
	weak_ref => 1,
);


=attribute is_prepared

[% s.name %] is true if this module has been prepared to be rendered.
Praparation includes indexing interesting information and early
validation checks.  [% s.name %] doesn't necessarily indicate whether
the preparation was successful, however.  cache_structure() uses it
internally to guard against re-entry, but other methods may also use
it to avoid callng cache_structure() unnecessarily.

=cut

has is_prepared => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=method cache_structure

[% s.name %] prepares the module to be rendered by performing all
prerequisite actions.  Data is collected and validated.  Intermediate
indexes are built.  And so on.

Returns nothing on success.  Returns a list of human-friend.y error
messages on failure.

=cut

sub cache_structure {
	my $self = shift();

	# 0. Don't re-prepare this module.
	# Comes first to avoid re-entry problems.

	return if $self->is_prepared();
	$self->is_prepared(1);

	warn "Preparing to render ", $self->package(), "...\n";

	my @errors;

	# 1. Collect directives that affect how the module is parsed.
	# This must be done before everything else.

	return @errors if push @errors, $self->docs()->cache_plexus_directives();

	# 2. Parse, build and collect documentation references.

	return @errors if push @errors, $self->docs()->cache_all_matter();

	# 3. Inherit documentation from base classes as needed.  Generate
	# documentation stubs for things that would otherwise go
	# unmentioned.
	#
	# Attributes come first since their accessors must be treated before
	# methods are.

	return @errors if push @errors, (
		$self->docs()->flatten_attributes(),
		$self->docs()->flatten_methods(),
	);

	# 4. Document things we can intuit from Moose and/or Class::MOP.
	# This may actually be rolled into flatten_attributes() since the
	# timing would be better there.

	return @errors if push @errors, $self->docs()->document_accessors();

	# 5. Do any final validations.  Is everything documented?  Do all
	# documentation sections reference actual implementation?  I'm not
	# entirely sure this step's needed so far, but it remains as a
	# reminder.

	return @errors if push @errors, (
		$self->docs()->validate_code(),
		$self->code()->validate_docs()
	);

	# We succeeded if we got this far.

	return;

	# SOME OLDER IDEAS TO CONSIDER.
	#
	# Gathering and grouping documentation into topics.  Not all
	# =methods are created equal.  For exmaple, POE's timer methods
	# could all be grouped under "=head2 Timer Methods" with a preamble.
	#
	# Hierarchical grouping.  Sometimes a group needs subgroups.  POE's
	# timer methods are a good example... there's a group that
	# identifies timers by name, and there's another set of methods that
	# returns and uses timer IDs.
	#
	# Possible syntax:
	#
	#   =method delay EVENT [, SECONDS [, CONTINUATION_DATA] ]
	#   SS<timers> XD<delay> X<relative timer>
	#
	# Where XD<> is a "definition" cross-reference.  The index could
	# highlight this entry as the definition for "delay".
	#
	# SS<timers> puts this method under the "timers" topic (section).
	#
	# X<relative timers> indexes this section under the "relative
	# timers" topic, but that topic doesn't _define_ it.
}


sub BUILD {
	my $self = shift();
	$self->verbose() and warn "  absorbing ", $self->pathname(), " ...\n";
}


no Moose;

1;

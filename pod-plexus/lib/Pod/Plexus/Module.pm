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

	warn "Preparing to render ", $self->package(), "...\n";

	# 0. Don't re-prepare this module.
	# Comes first to avoid re-entry problems.

	return if $self->is_prepared();
	$self->is_prepared(1);

	my @errors;

	# 1. Collect directives that affect how the module is parsed.
	# This must be done before everything else.

	# TODO - Considering removing this.  Let's see if we still need it.

	return @errors if push @errors, $self->docs()->cache_plexus_directives();

	# 2. Index code entities: attributes and methods.
	# Must be done before documentation is parsed.
	# Methods must come before attributes.

#	return @errors if push @errors, (
#		$self->code()->cache_all_methods(),
#		$self->code()->cache_all_attributes()
#	);

	# 3. Parse, build and collect documentation references.

	return @errors if push @errors, $self->docs()->cache_all_matter();

	# 4. Acquire documentation for things that have been inherited and
	# documented elsehwere.  As long as we don't already have them.

	return @errors if push @errors, (
		$self->docs()->flatten_methods(),
		$self->docs()->flatten_attributes()
	);

	# 5. Document things we can intuit from Moose and/or Class::MOP.

	return @errors if push @errors, $self->docs()->document_accessors();

	# 6. Make sure all code and documentation is accounted for.  This
	# step may be obsolete if everything is auto-docuemented as a last
	# resort.

	return @errors if push @errors, (
		$self->docs()->validate_code(),
		$self->code()->validate_docs()
	);

#	push @errors, $self->ensure_documentation();
#	return @errors if @errors;

	return;

	# ----------
	# TODO - Gathering or grouping documentation into topics.  The idea
	# is to render them as "=topic" so that Pod::Weaver can gather them.
	# Possible syntax:
	#
	# TODO - Gathering topics under higher level topics.  Hierarchical
	# documentation, if it's possible.  This would be nice to do without
	# building an explicit outline.
	#
	# =method delay EVENT [, SECONDS [, CONTINUATION DATA] ]
	# SS<timers> XD<delay> X<relative timer>
	#
	# Where XD<> is a "definition" cross-reference.  The index will
	# highlight this entry as the definition for "delay".
	#
	# SS<timers> puts this method in the "timers" topic.
	#
	# X<relative timers> indexes this section under the "relative
	# timers" topic, but it doesn't _define_ that topic.
	# ----------

	# NOTE - Attributes and methods are special.  It's okay for them to
	# be processed specially.

	# Once explicit code and documentation are associated, we can see
	# which remain undocumented and need to inherit documentation or
	# have boilerplate docs written.

	# TODO - For each undocumented attribute or method, try to find
	# documentation up the inheritance or role chain until we reach the
	# entity's implementation.

	# TODO - Load and parse all cross referenced modules.  We need
	# enough data to set xrefs, import inclusions, and import examples
	# from other, possibly non-Moose distributions.

	# TODO - Validate whether all cross referenced modules exist, within
	# and outside the current distribution.
}


sub BUILD {
	my $self = shift();
	$self->verbose() and warn "  absorbing ", $self->pathname(), " ...\n";
}


no Moose;

1;

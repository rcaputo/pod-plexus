package Pod::Plexus::Module;
# TODO - Edit pass 1 done.

use Moose;
use Pod::Plexus::Module::Code;
use Pod::Plexus::Module::Docs;


=abstract Represent and render a single module in a distribution.

=cut


=attribute docs

The "[% s.name %]" attribute contains a Pod::Plexus::Module::Docs
object that represents and builds upon the module's documentation.

=cut

has docs => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Module::Docs',
	lazy    => 1,
	default => sub {
		my $self = shift();
		Pod::Plexus::Module::Docs->new(
			module  => $self,
			verbose => $self->verbose(),
			blame   => $self->blame(),
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


=attribute docs

The "[% s.name %]" attribute contains a Pod::Plexus::Module::Code
object that represents the module's code.

=cut

has code => (
	is      => 'ro',
	isa     => 'Pod::Plexus::Module::Code',
	lazy    => 1,
	default => sub {
		my $self = shift();
		Pod::Plexus::Module::Code->new(
			module  => $self,
			verbose => $self->verbose(),
			blame   => $self->blame(),
		);
	},
	handles => {
		package              => 'package',
		get_method_source    => 'get_method_source',
		get_module_source    => 'get_module_source',
		get_attribute_source => 'get_attribute_source',
		add_matter_accessor  => 'add_matter_accessor',
		get_meta_module      => 'meta_module',
		find_matter          => 'find_matter',
	},
);


=boilerplate set_by_application

"[% s.name %]" is set by an application or plugin configuration.  For
example, Pod::Plexus::Cli sets it via the "--blame" command line
switch.

=cut


=attribute blame

The "[% s.name %]" attribute controls whether tracing information is
inserted into the resulting documentation.  The information tells
which objects generated each section of the documentation.  It's
useful for finding out the sources of strange output.

=include boilerplate set_by_application

=cut

has blame => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=attribute verbose

The "[% s.name %]" attribute controls whether tracing information is
written to the console's standard error channel.  The information
generally explains what's going on at any given time.  It's useful for
determining the location of warnings or runtime errors.

=include boilerplate set_by_application

=cut

has verbose => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=attribute pathname

"[% s.name %]" contains the relative path and name of the Module
currently being documented.

=cut

has pathname => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute distribution

"[% s.name %]" holds the Pod::Plexus::Distribution object that
represents the distribution containing modules being documented.  It
allows the current module to access its sibling modules through the
distribution containing them.

=cut

has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	required => 1,
	weak_ref => 1,
);


=attribute is_cached

"[% s.name %]" is true if this module's structure is currently being
cached or already has been.  "[% s.name %]" doesn't necessarily
indicate whether caching was successful.  The cache_structure() method
uses it to guard against re-entry, which would be redundant work at
best.

=cut

has is_cached => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=method cache_structure

[% s.name %]() analyzes and remembers a module's code and
documentation structure, and it.  The cached structure is used later
to find inherited documentation, generate new documentation, and
validate that the user-supplied documentation is correct.

Returns nothing on success, or a list of human-friendly error messages
when something failed.

=cut

sub cache_structure {
	my $self = shift();

	# 0. Don't re-prepare this module.
	# Comes first to avoid re-entry problems.

	return if $self->is_cached();
	$self->is_cached(1);

	warn "Caching structure for ", $self->package(), "...\n";

	my @errors;

	# 0. Cache all modules this one depends on.

	my $meta_module = $self->get_meta_module();

	if ($meta_module->can('linearized_isa')) {
		foreach my $dependency_class_name ($meta_module->linearized_isa()) {
			my $dependency_module = $self->distribution()->get_module(
				$dependency_class_name
			);
			next unless $dependency_module;
			$dependency_module->cache_structure();
		}
	}

	if ($meta_module->can('calculate_all_roles')) {
		foreach my $dependency_role_name ($meta_module->calculate_all_roles()) {
			my $dependency_module = $self->distribution()->get_module(
				$dependency_role_name
			);
			next unless $dependency_module;
			$dependency_module->cache_structure();
		}
	}

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

	# 5. Do any final validations.  Is everything documented?  Do all
	# documentation sections reference actual implementation?  I'm not
	# entirely sure this step's needed so far, but it remains as a
	# reminder.

	return @errors if push @errors, (
		$self->docs()->validate(),
		$self->code()->validate()
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

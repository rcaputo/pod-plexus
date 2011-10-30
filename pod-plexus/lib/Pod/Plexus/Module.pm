package Pod::Plexus::Module;

=abstract Represent and render a single module in a distribution.

=cut

use Moose;
use PPI;
use Pod::Elemental;
use Devel::Symdump;
use Storable qw(dclone);
use Carp qw(croak);

use feature 'switch';

use PPI::Lexer;
$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';

###
### Private data.
###

=attribute _ppi

[% ss.name %] contains a PPI::Document representing parsed module
being documented.  [% mod.package %] uses this to find source code to
include in the documentation, examine the module's implementation for
documentation clues, and so on.

=cut

has _ppi => (
	is      => 'ro',
	isa     => 'PPI::Document',
	lazy    => 1,
	default => sub { PPI::Document->new( shift()->pathname() ) },
);


=attribute _elemental

[% ss.name %] contains a Pod::Elemental::Document representing the
parsed POD from the module being documented.  [% mod.package %]
documents modules by inspecting and revising [% ss.name %], among
other things.

=cut

has _elemental => (
	is      => 'ro',
	isa     => 'Pod::Elemental::Document',
	lazy    => 1,
	default => sub { Pod::Elemental->read_file( shift()->pathname() ) },
);


has _verbose => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

###
### Basic public data.
###

=attribute pathname

[% ss.name %] contains the relative path and name of the file being
documented.

=cut

has pathname => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);


=attribute distribution

[% ss.name %] contains the Pod::Plexus::Distribution object that
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


=attribute package

[% ss.name %] contains the module's main package name.  Its main use
is in template expansion, via the "mod.package" expression.

=cut

has package => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my $main_package = $self->_ppi()->find_first('PPI::Statement::Package');
		return "" unless $main_package;

		return $main_package->namespace();
	},
);


sub abstract {
	my $self = shift();

	$self->prepare_to_render() unless $self->is_prepared();
	my $abstract = $self->get_reference(
		'Pod::Plexus::Docs::Abstract'
	);
	die "No abstract defined for ", $self->package(), "\n" unless $abstract;

	return $abstract->abstract();
}

###
### Module code structure.
###

use Pod::Plexus::Code::Method;
use Pod::Plexus::Code::Attribute;

=attribute meta_entity

[% ss.name %] contains a meta-object that describes the class being
documented from Class::MOP's perspective.  It allows Pod::Plexus to
introspect the class and do many wonderful things with it, such as
inherit documentation from parent classes.

As of this writing however, it's beyond the author's ability to
reliable inherit attribute and method documentation from higher up the
class and role chain.  Hopefully someone with better Meta and MOP
chops can step up.

=cut

#use Class::MOP::Class;

has meta_entity => (
	is            => 'rw',
	isa           => 'Class::MOP::Module',
	lazy          => 1,
	default       => sub {
		my $self = shift();

		my $class_name = $self->package();
		return unless $class_name;

		# Must be loaded to be introspected.
		Class::MOP::load_class($class_name);
		my $x = Class::MOP::Class->initialize($class_name);
		warn ref($x);
		return $x;
	},
);


=attribute attributes

[% ss.name %] contains an hash of all identified attributes in the
class being documented.  They are keyed on attribute name, and values
are Pod::Plexus::Code::Attribute objects.

=cut

has attributes => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Code::Attribute]',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		_add_attribute  => 'set',
		_has_attribute  => 'exists',
		_get_attribute  => 'get',
		_get_attributes => 'values',
	},
);


=attribute methods

[% ss.name %] contains an hash of all identified methods in the class
being documented.  They are keyed on method name, and values are
Pod::Plexus::Code::Method objects.

=cut

has methods => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Code::Method]',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		_add_method  => 'set',
		_has_method  => 'exists',
		_get_method  => 'get',
		_get_methods => 'values',
	},
);

###
### Class taxonomy structure.
###

### Sources of imported symbols.

=attribute imports

[% ss.name %] contains a hash of all modules identified as being
required or used by the module being documented.  This hash is used to
find imported symbols, if needed to completely document the module.

=cut

=method add_import

[% ss.name %] is a hash setter that adds the name of a used module.  It
takes two parameters: the module's name, and an unused value for the
hash.

=cut

=method get_imports

[% ss.name %] is a hash accessor that returns all unique imported
module names.  It just returns the "imports" attribute's keys().

=cut

has imports => (
	is      => 'rw',
	isa     => 'HashRef[Str]',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		add_import  => 'set',
		get_imports => 'keys',
	},
);

### Base classes.

=attribute base_classes

[% ss.name %] contains a hash of all immediate base classes of the
class being documented.  This hash is used to find inherited symbols,
if needed to completely document the module.

=method add_base_class

[% ss.name %] is a hash setter that adds the name of a base class.  It
takes two parameters: the base class name, and an unused value for the
hash.

=cut

=method get_base_classes

[% ss.name %] is a hash accessor that returns all unique base class
names for this module.  It just returns the "base_classes" attribute's
keys().

=cut

has base_classes => (
	is       => 'rw',
	isa      => 'HashRef[Str]',
	traits   => [ 'Hash' ],
	handles  => {
		add_base_class   => 'set',
		get_base_classes => 'keys',
	},
);

### Roles.

=attribute roles

[% ss.name %] contains a hash of all roles directly consumed by the
class being documented.  This hash is used to find consumed symbols,
if needed to completely document the module.

=cut

=method add_role

[% ss.name %] is a hash setter that adds the name of a consumed role.
It takes two parameters: the role name, and an unused value for the
hash.

=cut

=method get_roles

[% ss.name %] is a hash accessor that returns all unique role names
consumed by this module.  It just returns the "roles" attribute's
keys().

=cut

has roles => (
	is       => 'rw',
	isa      => 'HashRef[Str]',
	traits   => [ 'Hash' ],
	handles  => {
		add_role  => 'set',
		get_roles => 'keys',
	},
);

###
### Documentation structure.
###

# TODO - Make dynamic based on whatever is installed.

my @reference_classes = qw(
	Abstract Cross Demacro Code::Attribute Code::Method
	Example Include Index Macro
);

my %reference_class;

foreach my $reference_class (@reference_classes) {
	my $full_class = "Pod::Plexus::Docs::$reference_class";
	my $full_file  = "$full_class.pm";
	$full_file     =~ s/::/\//g;

	require $full_file;
	$full_class->import();

	$reference_class{$full_class->POD_COMMAND} = $full_class;
}

has references => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Docs]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_really_add_reference => 'set',
		_has_reference        => 'exists',
		_get_reference        => 'get',
		_get_references       => 'values',
	},
);

sub _add_reference {
	my ($self, $include) = @_;

	my $key = $include->key();
	return if $self->_has_reference($key);
	$self->_really_add_reference($key, $include);
}

### Skipping attributes.

=attribute skip_attributes

[% ss.name %] is a hash keyed on the names of attributes supplied by
the "=skip attribute" directive.  These attributes won't be
automatically documented, nor will Pod::Plexus complain if they aren't
documented.

Values don't matter, although the skip_attribute() method will supply
one.  Literally, the number 1.

=method is_skippable_attribute

[% ss.name %] tests whether a given attribute name exists in
skip_attributes().

=cut

has skip_attributes => (
	is      => 'rw',
	isa     => 'HashRef',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		_is_skippable_attribute => 'exists',
		_skip_attribute        => 'set',
	}
);


sub is_skippable_attribute {
	my ($self, $attribute_name) = @_;
	return 1 if $attribute_name =~ /^_/;
	return $self->_is_skippable_attribute($attribute_name);
}


=method skip_attribute

[% ss.name %] is used by the "=skip attribute" directive to set the
attribute name to skip.

=cut

sub skip_attribute {
	my $self = shift();
	$self->_skip_attribute($_, 1) foreach @_;
}

### Skipping methods.

=attribute skip_methods

[% ss.name %] is a hash keyed on the names of methods supplied by the
"=skip method" directive.  These methods won't be automatically
documented, nor will Pod::Plexus complain if they aren't documented.

=method is_skippable_method

[% ss.name %] tests whether the named method exists in skip_methods.

=cut

has skip_methods => (
	is      => 'rw',
	isa     => 'HashRef',
	traits  => [ 'Hash' ],
	default => sub {
		{
			BUILDALL    => 1,
			BUILDARGS   => 1,
			DEMOLISHALL => 1,
			DESTROY     => 1,
			DOES        => 1,
			VERSION     => 1,
			can         => 1,
			does        => 1,
			dump        => 1,
			meta        => 1,
			new         => 1,
		}
	},
	handles => {
		_is_skippable_method => 'exists',
		_skip_method        => 'set',
	}
);


sub is_skippable_method {
	my ($self, $method_name) = @_;
	return 1 if $method_name =~ /^_/;
	return $self->_is_skippable_method($method_name);
}


=method skip_method

Values don't matter, although the skip_attribute() method will supply
one.  Literally, the number 1.

=cut

sub skip_method {
	my $self = shift();
	$self->_skip_method($_, 1) foreach @_;
}


sub skip_all {
	my $self = shift();
	$self->skip_attribute(@_);
	$self->skip_method(@_);
}

###
### Validation pass.
###

=method get_referents

[% ss.name %] returns a list of every other module referred to by this
module.  The Pod::Plexus::Distribution uses it to find new referents.

=cut

sub get_referents {
	my $self = shift();

	my %referents;

	$referents{$_} = $_ foreach (
		#$self->get_imports(),
		$self->get_base_classes(),
		$self->get_roles(),
		( map { $_->module() } $self->_get_references() ),
	);

	return values %referents;
}


=method get_reference

[% ss.name %] returns a single reference, keyed on the referent type,
module, and optional symbol name.

=cut

sub get_reference {
	my ($self, $type, $module, $symbol) = @_;

	$module //= $self->package();
	$symbol //= "";

	my $reference_key = Pod::Plexus::Docs->calc_key(
		$type, $module, $symbol
	);

	return unless $self->_has_reference($reference_key);
	return $self->_get_reference($reference_key);
}

###
### Final render.
###

=method render_as_pod

[% ss.name %] generates and returns the POD for the class being
documented, after all is send and done.

=cut

sub render_as_pod {
	my $self = shift();

	# Render each Pod::Elemental element.
	# Contents get to be expanded as templates.

	my $doc = $self->_elemental()->children();

	my $rendered_documentation = "";

	my @queue = @$doc;
	NODE: while (@queue) {
		my $next = shift @queue;

		if ($next->isa('Pod::Plexus::Docs')) {
			unshift @queue, $next->as_pod_elementals();
			next NODE;
		}

		my $next_pod = $next->as_pod_string();

		# Expand $next_pod as a template.
		# TODO

		$rendered_documentation .= $next_pod;

		next NODE unless $next->can("children");

		my $sub_children = $next->children();
		unshift @queue, @$sub_children if @$sub_children;
	}

	return $rendered_documentation;
}


=attribute is_prepared

[% ss.name %] is true if this module has been prepared to be rendered.
Praparation includes indexing interesting information and early
validation checks.  [% ss.name %] doesn't necessarily indicate whether
the preparation was successful, however.  prepare_to_render() uses it
internally to guard against re-entry, but other methods may also use
it to avoid callng prepare_to_render() unnecessarily.

=cut

has is_prepared => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=method prepare_to_render

[% ss.name %] prepares the module to be rendered by performing all
prerequisite actions.  Data is collected and validated.  Intermediate
indexes are built.  And so on.

Returns nothing on success.  Returns a list of human-friend.y error
messages on failure.

=cut

sub prepare_to_render {
	my ($self, $errors) = @_;

	warn "Preparing to render ", $self->package(), "...\n";

	# 0. Don't re-prepare this module.
	# Comes first to avoid re-entry problems.

	return if $self->is_prepared();
	$self->is_prepared(1);

	# 1. Index code entities: attributes and methods.
	# Must be done before documentation is parsed.
	# Methods must come before attributes.

	$self->index_code_attributes($errors);
	$self->index_code_methods($errors);
	return if @$errors;

	# 2. Collect directives that affect how the module is parsed.
	# This must be done before everything else.

	$self->extract_doc_commands($errors, 'extract_doc_directive_skip');
	return if @$errors;

	# 3. Parse, build and collect documentation references.

	$self->index_doc_references($errors);
	return if @$errors;

	# 4. Acquire documentation for things that have been inherited and
	# documented elsehwere.  As long as we don't already have them.

	$self->assimilate_ancestor_method_documentation($errors);
	$self->assimilate_ancestor_attribute_documentation($errors);
	return if @$errors;

	# 5. Document things we can intuit from Moose and/or Class::MOP.

	$self->document_accessors($errors);
	return if @$errors;

	# 6. Make sure every recognizable code entity has corresponding
	# documentation.

	foreach my $attribute_name (keys %{$self->attributes()}) {
		next if $self->is_skippable_attribute($attribute_name);
		#$self->_get_attribute($attribute_name)->validate($self, $errors);
	}

	foreach my $method_name (keys %{$self->methods()}) {
		next if $self->is_skippable_method($method_name);
		#$self->_get_method($method_name)->validate($self, $errors);
	}

	return if @$errors;

#	$self->ensure_documentation($errors);
#	return if @$errors;

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

###
### Collect data from the documentation, but leave markers behind.
###

=method index_doc_references

[% ss.name %] examines each Pod::Elemental command node.  Ones that
are listed as known reference commands, such as "=abstract" or
"=example", are parsed and recorded by their appropriate
Pod::Plexus::Docs classes.

All other Pod::Elemental commands are ignored.

=cut

sub index_doc_references {
	my ($self, $errors, $method) = @_;

	my $doc = $self->_elemental()->children();

	my $i = @$doc;
	NODE: while ($i--) {
		my $node = $doc->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');
		next NODE unless exists $reference_class{$node->{command}};

		my @new_errors;

		my $reference_class = $reference_class{$node->{command}};
		my $reference = $reference_class->create(
			module => $self,
			errors   => \@new_errors,
			distribution  => $self->distribution(),
			node     => $node,
		);

		if (@new_errors) {
			push @$errors, @new_errors;
			next NODE;
		}

		# It's legal for a reference not to be created.
		next NODE unless $reference;

		# Record the reference for random access.
		$self->_add_reference($reference);

		# Splice the reference into place for sequential access.
		splice @$doc, $i, 1, $reference;
		# Roll up trailing documentation.
		my $j = $i + 1;
		while ($j < @$doc and $reference->consume_element($doc->[$j])) {
			splice @$doc, $j, 1;
		}
	}
}

###
### Extract and remove data from documentation.
###

=method extract_doc_commands

[% ss.name %] iterates the Pod::Elemental::Element::Generic::Command
elements of a module's documentation.  Its single parameter is the
name of a $self method to call for each command node.  Those methods
should parse the command, enter appropriate data into the object, and
return true if the command paragraph should be removed from the
documentation.  A false return value will leave the command paragraph
in place.

=cut

sub extract_doc_commands {
	my ($self, $errors, $method) = @_;

	my $doc = $self->_elemental()->children();

	my $i = @$doc;
	NODE: while ($i--) {
		my $node = $doc->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		my $result = $self->$method($errors, $doc->[$i]);
		next NODE unless $result;

		# TODO - Do we need a better means to remove an extracted command
		# from the POD, closing up the hole that's left?  We need to be
		# smart about the trailing cut, since it may terminate a section
		# of multiple commands.  If we simply take it out, then we break
		# the POD preceding the command.

		# TODO - For now, extracted commands and their content are
		# replaced by "=pod" and a blank paragraph.  This may be enough of
		# a no-op for long-term use.

		splice(
			@$doc, $i, 1,
			Pod::Elemental::Element::Generic::Command->new(
				command => 'pod',
				content => "\n",
			),
			Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
		);

		# TODO - Better check for $result being an entity?
		next NODE unless ref $result;

		# The return value is an entity.  This means append the following
		# text to its documentation.

		my $j = $i + 2;
		TEXT: while ($j < @$doc) {
			unless ($doc->[$j]->isa('Pod::Elemental::Element::Generic::Command')) {
				$result->push_documentation( splice(@$doc, $j, 1) );
				next TEXT;
			}

			if (
				$doc->[$j]->{command} eq 'cut' or
				$doc->[$j]->{command} eq 'attribute' or
				$doc->[$j]->{command} eq 'method' or
				$doc->[$j]->{command} eq 'xref' or
				$doc->[$j]->{command} =~ /^head/
			) {
				last TEXT;
			}

			$result->push_documentation( splice(@$doc, $j, 1) );
		}

		$result->cleanup_documentation();
	}
}


=method extract_doc_directive_skip

[% ss.name %] examines a single Pod::Elemental command node.  If it's
a "=skip" directive, its data is entered into the [% mod.name %]
object, and [% ss.name %] returns true.  False is returned for all
other nodes.

=demacro extract_doc_command_callback

=cut

=macro extract_doc_command_callback

This method is a callback to extract_doc_command().  That other method
is a generic iterator to walk through the Pod::Elemental document in
memory and remove nodes that have been successfully parsed.  Node
removal is triggered by callbacks, such as [% ss.name %] returning a
true value.

As with all [% mode.name %] parsers, only the Pod::Elemental data in
memory is affected.  The source on disk is untouched.

=cut

sub extract_doc_directive_skip {
	my ($self, $errors, $node) = @_;

	return unless $node->{command} eq 'skip';

	my ($entity_type, $entity_name) = (
		$node->{content} =~ /^\s* (attribute|method|all) \s+ (\S.*?) \s*$/x
	);

	my $skip_method = "skip_$entity_type";
	$self->$skip_method($entity_name);

	return 1;
}

###
### Index data we can glean from the code.
### These things are NOT extracted.
###

=method index_code_attributes

Find and register all attributes known by Class::MOP to exist.

This is a helper method called by index().

=cut

sub index_code_attributes {
	my ($self, $errors) = @_;

	$self->_verbose() and warn(
		"  indexing ", $self->package(), " code attributes...\n"
	);

	my $meta = $self->meta_entity();

	ATTRIBUTE: foreach my $name ($meta->get_attribute_list()) {
		#next ATTRIBUTE if $self->is_skippable_attribute($name);

		$self->_verbose() and warn(
			"    indexing ", $self->package(), " attribute $name\n"
		);

		my $attribute = $meta->get_attribute($name);

		# TODO - How to report the places where it's defined?  Can it be?
		if ($self->_has_attribute($name)) {
			push @$errors, (
				"Attribute $name defined more than once.  Second one is" .
				" at " . $self->pathname() . " line $attribute->{start_line}"
			);
			next ATTRIBUTE;
		}

		my $entity = Pod::Plexus::Code::Attribute->new(
			meta_entity => $attribute,
			name        => $name,
		);

		$self->_add_attribute($name, $entity);

		# Scratchpad the attribute's definition information for
		# inheritance checking later.


		# Add associated methods.

		foreach my $method (values %{$attribute->handles() // {}}) {
			#my $entity = $self->index_code_method($errors, $method);

			# TODO - Indicate the entity came from an attribute.
		}

		if ($attribute->has_read_method()) {
			my $reader_name = $attribute->get_read_method();
			my $reader_body = $meta->get_method($reader_name);
			$self->index_code_method($errors, $reader_body);

			if ($attribute->has_write_method()) {
				my $writer_name = $attribute->get_write_method();

				if ($reader_name ne $writer_name) {
					my $writer_body = $meta->get_method($writer_name);
					$self->index_code_method($errors, $writer_body);
				}
			}
		}
	}
}


=method index_code_methods

Find and register all methods known by Class::MOP to exist in the
class being documented.

This is a helper method called by index().

=cut

sub index_code_methods {
	my ($self, $errors) = @_;

	$self->_verbose() and warn(
		"  indexing ", $self->package(), " code methods...\n"
	);

	# TODO
	#
	# get_method_list() returns a list of names for the method defined
	# by this particular class.
	#
	# get_all_methods() returns a list of all Class::MOP::Method objects
	# flattened into this class.  Ones whose names aren't in the
	# get_method_list() list are inherited somehow.
	#
	#   Only available from Class::MOP::Class.
	#   Roles don't have it.
	#
	# find_all_methods_by_name($name) returns all instances of the
	# method in the inheritance tree.  Order is unspecified, but it
	# probably means something.
	#
	#   Class::MOP::Class and Moose::Meta::Role have this.
	#
	# TODO - Probably should subclass Pod::Plexus::Module for the
	# different kinds of module.  Meanwhile, I'm going to get all
	# polymorphic here.

	my $meta = $self->meta_entity();

	my @methods = (
		$meta->can('get_all_methods')
		? (
			grep { ! $self->_has_method($_->name()) }
			sort { $a->name() cmp $b->name() }
			$meta->get_all_methods()
		)
		: (map { $meta->get_method($_) } sort $meta->get_method_list())
	);

	METHOD: foreach my $method (@methods) {
		$self->index_code_method($errors, $method);
	}
}

sub index_code_method {
	my ($self, $errors, $method) = @_;

	# TODO
	#
	# get_method_list() returns a list of names for the methoddefined by
	# this particular class.
	#
	# get_all_methods() returns a list of all Class::MOP::Method objects
	# flattened into this class.  Ones whose names aren't in the
	# get_method_list() list are inherited somehow.
	#
	#   Only available from Class::MOP::Class.
	#   Roles don't have it.
	#
	# find_all_methods_by_name($name) returns all instances of the
	# method in the inheritance tree.  Order is unspecified, but it
	# probably means something.
	#
	#   Class::MOP::Class and Moose::Meta::Role have this.
	#
	# TODO - Probably should subclass Pod::Plexus::Module for the
	# different kinds of module.  Meanwhile, I'm going to get all
	# polymorphic here.

	#my $name = $method->name();

	#returnif $self->is_skippable_method($name);

	#my $method = $meta->get_method($name);

	# Assume all-caps methods are constants if they also have empty
	# prototypes.
	#
	# TODO - Is there a better way to detect constants vs. methods?

	# TODO - Remove after debugging?
	confess "??? $method" unless ref($method);

	my $method_name = $method->name();

	$self->_verbose() and warn(
		"    indexing ", $self->package(), " method $method_name\n"
	);

	if ($method_name =~ /^[A-Z0-9_]+$/) {
		my $proto = prototype($method->body());
		return if defined $proto and $proto eq '';
	}

	# TODO - How to report the places where it's defined?  Can it be?
	return if $self->_has_method($method_name);

	my $entity = Pod::Plexus::Code::Method->new(
		name        => $method_name,
	);

	$self->_add_method($method_name, $entity);

	return $entity;
}

###
### Validate attribute and method docs.
###

sub document_accessors {
	my ($self, $errors) = @_;

	#die "working on the magic";

	my $class_meta = $self->meta_entity();

	foreach my $attribute ($self->_get_attributes()) {

		my $attribute_meta = $attribute->meta_entity();
		my $attribute_name = $attribute_meta->name();

		my %handles = %{$attribute_meta->handles() // {}};
		while (my ($api_name, $impl_name) = each %handles) {

			my $api_entity = Pod::Plexus::Code::Method->new(name => $api_name);
			$self->_add_method($api_name, $api_entity);

			my $method_reference = Pod::Plexus::Docs::Code::Method->new(
				module => $self,
				errors   => $errors,
				distribution  => $self->distribution(),
				name     => $api_name,
				node     => Pod::Elemental::Element::Generic::Command->new(
					command    => "method",
					content    => "$api_name\n",
					start_line => -__LINE__,
				),
			);

			# Don't document this if we already have it.
			next if $self->_has_reference($method_reference->key());

			my @body = (
				Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						"$api_name() exposes $impl_name() from the attribute " .
						"\"$attribute_name\".\n"
					),
				),
				Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
			);

			$method_reference->push_body(@body);
			$method_reference->push_documentation(@body);
			$method_reference->push_cut();

			$self->_add_reference($method_reference);

			push @{$self->_elemental()->children()}, (
				Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
				$method_reference,
			);
		}

		if ($attribute_meta->has_read_method()) {
			my $reader_name = $attribute_meta->get_read_method();

			if ($attribute_meta->has_write_method()) {
				my $writer_name = $attribute_meta->get_write_method();

				if ($reader_name eq $writer_name) {
					$self->_document_rw_accessor(
						$errors, $attribute->name(), $reader_name
					);
				}
				else {
					$self->_document_ro_accessor(
						$errors, $attribute->name(), $reader_name
					);

					$self->_document_wo_accessor(
						$errors, $attribute->name(), $writer_name
					);
				}
			}
			else {
				$self->_document_ro_accessor(
					$errors, $attribute->name(), $reader_name
				);
			}
		}
	}
}

use Carp qw(cluck);

sub _document_ro_accessor {
	my ($self, $errors, $attribute_name, $method_name) = @_;
	$self->_document_accessor(
		$errors, $attribute_name, $method_name, 'a read-only accessor'
	);
}

sub _document_wo_accessor {
	my ($self, $errors, $attribute_name, $method_name) = @_;
	$self->_document_accessor(
		$errors, $attribute_name, $method_name, 'a write-only mutator'
	);
}

sub _document_rw_accessor {
	my ($self, $errors, $attribute_name, $method_name) = @_;
	$self->_document_accessor(
		$errors, $attribute_name, $method_name, 'a read-write mutator'
	);
}

sub _document_accessor {
	my ($self, $errors, $attribute_name, $method_name, $accessor_type) = @_;

	my $method_reference = Pod::Plexus::Docs::Code::Method->new(
		module => $self,
		errors   => $errors,
		distribution  => $self->distribution(),
		name     => $method_name,
		node     => Pod::Elemental::Element::Generic::Command->new(
			command    => "method",
			content    => "$method_name\n",
			start_line => -__LINE__,
		),
	);

	# Don't document this if we already have it.
	return if $self->_has_reference($method_reference->key());

	my @body = (
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		Pod::Elemental::Element::Generic::Text->new(
			content => (
				"$method_name() is $accessor_type " .
				"for the \"$attribute_name\" attribute.\n"
			),
		),
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
	);

	$method_reference->push_body(@body);
	$method_reference->push_documentation(@body);
	$method_reference->push_cut();

	$self->_add_reference($method_reference);

	push @{$self->_elemental()->children()}, (
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		$method_reference,
	);
}

sub assimilate_ancestor_method_documentation {
	my ($self, $errors) = @_;

	my $meta       = $self->meta_entity();
	my $this_docs  = $self->_elemental()->children();
	my $this_class = $self->package();
	my %class_docs;

	my $get_method_names = (
		($meta->isa("Moose::Meta::Role"))
		? "get_method_list"
		: "get_all_method_names"
	);

	METHOD: foreach my $method_name ($meta->$get_method_names()) {

		next METHOD if $self->is_skippable_method($method_name);

		my $thunk_name = "_pod_plexus_documents_method_$method_name\_";
		my $docs = eval { $this_class->$thunk_name() };

		# The method comes from an outside source.

		next METHOD unless $docs;

		# The method is already documented by this class.

		next METHOD if $docs->module() == $self;

		# The method is documented in a superclass.

		$self->_document_inherited_method(
			$this_docs,
			$this_class,
			$docs->module()->package(),
			$method_name,
			$self,
			$errors,
		);
	}
}

sub assimilate_ancestor_attribute_documentation {
	my ($self, $errors) = @_;

	my $meta       = $self->meta_entity();
	my $this_docs  = $self->_elemental()->children();
	my $this_class = $self->package();
	my %class_docs;

	my @attribute_names;
	if ($meta->isa("Moose::Meta::Role")) {
		@attribute_names = $meta->get_attribute_list();
	}
	else {
		@attribute_names = map { $_->name() } $meta->get_all_attributes();
	}

	ATTRIBUTE: foreach my $attribute_name (@attribute_names) {

		next ATTRIBUTE if $self->is_skippable_attribute($attribute_name);

		my $thunk_name = "_pod_plexus_documents_attribute_$attribute_name\_";
		my $docs = eval { $this_class->$thunk_name() };

		# The attribute comes from an outside source.

		next ATTRIBUTE unless $docs;

		# The attribute is already documented by this class.

		next ATTRIBUTE if $docs->module() == $self;

		# The attribue is documented in a superclass.

		$self->_document_inherited_attribute(
			$this_docs,
			$this_class,
			$docs->document()->package(),
			$attribute_name,
			$self,
			$errors,
		);
	}
}

###
### Build documentation.
###

# TODO - _document_inherited_method() and
# _document_inherited_attribute() need to be refactored.  They're a
# copy/paste job with a lot of commonalities.

sub _document_inherited_method {
	my (
		$self, $this_docs, $this_class, $class_name, $method_name,
		$module, $errors,
	) = @_;

	my $method_reference = Pod::Plexus::Docs::Code::Method->new(
		module => $self,
		errors   => $errors,
		distribution  => $self->distribution(),
		name     => $method_name,
		node     => Pod::Elemental::Element::Generic::Command->new(
			command    => "method",
			content    => "$method_name\n",
			start_line => -__LINE__,
		),
	);

	my $include_reference = Pod::Plexus::Docs::Include->new(
		errors   => $errors,
		module => $self,
		name     => $method_name,
		distribution  => $self->distribution(),
		node     => Pod::Elemental::Element::Generic::Command->new(
			command    => "include",
			content    => "$class_name method $method_name",
			start_line => -__LINE__,
		),
	);

	$self->_add_reference($method_reference);
	$self->_add_reference($include_reference);

	my @body = (
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		$include_reference,
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		Pod::Elemental::Element::Generic::Text->new(
			content => (
				"It is inherited from L<$class_name|$class_name/$method_name>.\n"
			),
		),
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		Pod::Elemental::Element::Generic::Command->new(
			command => "cut",
			content => "\n",
		),
	);

	$method_reference->push_body(@body);
	$method_reference->push_documentation(@body);

	push @$this_docs, (
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		$method_reference,
	);
}

sub _document_inherited_attribute {
	my (
		$self, $this_docs, $this_class, $class_name, $attribute_name,
		$module, $errors,
	) = @_;

	unless ($self->_has_attribute($attribute_name)) {
		my $attribute = $self->meta_entity()->find_attribute_by_name(
			$attribute_name
		);

		unless ($attribute) {
			push @$errors, (
				"Class $this_class references unknown attribute $attribute_name"
			);
			return;
		}

		# Dummy attribute entity to satisfy validity checks.

		$self->_add_attribute(
			$attribute_name,
			Pod::Plexus::Code::Attribute->new(
				meta_entity => $attribute,
				name        => $attribute_name,
			)
		);
	}

	my $attribute_reference = Pod::Plexus::Docs::Code::Attribute->new(
		errors   => $errors,
		module => $self,
		name     => $attribute_name,
		distribution  => $self->distribution(),
		node     => Pod::Elemental::Element::Generic::Command->new(
			command    => "attribute",
			content    => "$attribute_name\n",
			start_line => -__LINE__,
		),
	);

	my $include_reference = Pod::Plexus::Docs::Include->new(
		errors   => $errors,
		module => $self,
		name     => $attribute_name,
		distribution  => $self->distribution(),
		node     => Pod::Elemental::Element::Generic::Command->new(
			command    => "include",
			content    => "$class_name attribute $attribute_name",
			start_line => -__LINE__,
		),
	);

	$self->_add_reference($attribute_reference);
	$self->_add_reference($include_reference);

	my @body = (
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		$include_reference,
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		Pod::Elemental::Element::Generic::Text->new(
			content => (
				"It is inherited from L<$class_name|$class_name/$attribute_name>.\n"
			),
		),
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		Pod::Elemental::Element::Generic::Command->new(
			command => "cut",
			content => "\n",
		),
	);

	$attribute_reference->push_body(@body);
	$attribute_reference->push_documentation(@body);

	push @$this_docs, (
		Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		$attribute_reference,
	);
}

###
### Dereference documentation references.
###

=method sub

[% ss.name %] returns the code for a particular named subroutine or
method in the class being documented.  This is used to render code
examples from single subroutines.

=cut

sub sub {
	my ($self, $sub_name) = @_;

	my $subs = $self->_ppi()->find(
		sub {
			$_[1]->isa('PPI::Statement::Sub') and
			defined($_[1]->name()) and
			$_[1]->name() eq $sub_name
		}
	);

	confess $self->package(), " doesn't define sub $sub_name" unless (
		$subs and @$subs
	);

	die $self->package(), " defines too many subs $sub_name" if @$subs > 1;

	return $subs->[0]->content();
}


=method code

[% ss.name %] returns the code portion of the file represented by this
module.  This is used to render code examples by quoting entire
modules.

=cut

sub code {
	my $self = shift();

	my $out = $self->_ppi()->clone();
	$out->prune('PPI::Statement::End');
	$out->prune('PPI::Statement::Data');
	$out->prune('PPI::Token::Pod');

	return $out->serialize();
}

###
### Debugging.
###

sub BUILD {
	my $self = shift();
	$self->_verbose() and warn "  absorbing ", $self->pathname(), " ...\n";
}


=method elementaldump

[% ss.name %] is a debugging helper method to print the Pod::Elemental
data for the class being documented, in YAML format.

=cut

sub elementaldump {
	my $self = shift();
	use YAML;
	print YAML::Dump($self->_elemental());
	exit;
}


=method ppidump

[% ss.name %] is a debugging helper method to print the PPI document
for the class being documented, in PPI::Dumper format.

=cut

sub ppidump {
	my $self = shift();
	use PPI::Dumper;
	my $d = PPI::Dumper->new( $self->_ppi() );
	$d->print();
	exit;
}

no Moose;

1;

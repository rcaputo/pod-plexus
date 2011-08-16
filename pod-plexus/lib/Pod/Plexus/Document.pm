package Pod::Plexus::Document;

=abstract Represent and render a single Pod::Plexus document.

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

use constant {
	SCOPE_LOCAL    => 0x0001,
	SCOPE_FOREIGN  => 0x0002,

	TYPE_SUB       => 0x0010,
	TYPE_PACKAGE   => 0x0020,
	TYPE_SECTION   => 0x0040,
	TYPE_FILE      => 0x0080,

	MOD_EXPLICIT   => 0x0100,
	MOD_IMPLICIT   => 0x0200,
};

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


=attribute library

[% ss.name %] contains the Pod::Plexus::Library object that represents
the entire library of documents.  It allows the current document to
find and reference the library and other documents within it.

=cut

has library => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Library',
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

	$self->collect_data() unless $self->collected_data();
	my $abstract = $self->get_reference('Pod::Plexus::Reference::Abstract');
	die "No abstract defined for ", $self->package(), "\n" unless $abstract;

	return $abstract->abstract();
}

###
### Module code structure.
###

use Pod::Plexus::Entity::Method;
use Pod::Plexus::Entity::Attribute;

=attribute mop_class

[% ss.name %] contains a Class::MOP::Class object that describes the
class being documented from Class::MOP's perspective.  It allows
Pod::Plexus to introspect the class and do many wonderful things with
it, such as inherit documentation from parent classes.

As of this writing however, it's beyond the author's ability to
reliable inherit attribute and method documentation from higher up the
class and role chain.  Hopefully someone with better Meta and MOP
chops can step up.

=cut

use Class::MOP::Class;

has mop_class => (
	is            => 'rw',
	isa           => 'Class::MOP::Class',
	lazy          => 1,
	default       => sub {
		my $self = shift();

		my $class_name = $self->package();
		return unless $class_name;

		# Must be loaded to be introspected.
		Class::MOP::load_class($class_name);
		return Class::MOP::Class->initialize($class_name);
	},
);


=attribute attributes

[% ss.name %] contains an hash of all identified attributes in the
class being documented.  They are keyed on attribute name, and values
are Pod::Plexus::Entity::Attribute objects.

=cut

has attributes => (
	is      => 'rw',
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Entity::Attribute]',
	traits   => [ 'Hash' ],
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
Pod::Plexus::Entity::Method objects.

=cut

has methods => (
	is     => 'rw',
	isa    => 'HashRef[Pod::Plexus::Entity::Method]',
	traits => [ 'Hash' ],
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

index_code_inclusions() populates it by analyzing the module's source
code for telltale statements.

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

index_code_inclusions() populates it by analyzing the module's source
code for telltale statements.

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

index_code_inclusions() populates it by analyzing the module's source
code for telltale statements.

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

my @reference_classes = qw(
	Abstract Cross Demacro Entity::Attribute Entity::Method
	Example::Module Example::Method Include Index Macro
);

my %pod_prio_commands;
my %pod_commands;

foreach my $reference_class (@reference_classes) {
	my $full_class = "Pod::Plexus::Reference::$reference_class";
	my $full_file  = "$full_class.pm";
	$full_file     =~ s/::/\//g;

	require $full_file;
	$full_class->import();

	$pod_commands{$full_class->POD_COMMAND} =
	$pod_prio_commands{$full_class->POD_PRIORITY}{$full_class->POD_COMMAND} = (
		$full_class
	);
}

has references => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Reference]',
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
		is_skippable_attribute => 'exists',
		_skip_attribute        => 'set',
	}
);


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
		is_skippable_method => 'exists',
		_skip_method        => 'set',
	}
);


=method skip_method

Values don't matter, although the skip_attribute() method will supply
one.  Literally, the number 1.

=cut

sub skip_method {
	my $self = shift();
	$self->_skip_method($_, 1) foreach @_;
}

###
### Validation pass.
###

=method get_referents

[% ss.name %] returns a list of every module referred to by this
document.  The Pod::Plexus::Library uses it to find new referents.

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

	my $reference_key = Pod::Plexus::Reference->calc_key(
		$type, $module, $symbol
	);

	return unless $self->_has_reference($reference_key);
	return $self->_get_reference($reference_key);
}

###
### Final render.
###

=method render

[% ss.name %] generates and returns the POD for the class being
documented, after all is send and done.

=cut

sub render {
	my $self = shift();

	my $elemental = $self->_elemental();

	# TODO - I can see why autoboxing is sexy.

	# TODO - Render each POD section separately so we can have variables
	# like ss.name to mean the section name.

	my $input = "";
	my @queue = @{$self->_elemental()->children()};
	while (@queue) {
		my $next = shift @queue;
		$input .= $next->as_pod_string();

		next unless $next->can("children");
		my $sub_children = $next->children();
		unshift @queue, @$sub_children if @$sub_children;
	}

	my $output = "";

	my %vars = (
		doc     => $self,
		lib     => $self->library(),
		module  => $self->package(),
	);

	# TODO - Temporary, for debugging.
	$output = $input;

#	$self->library()->_template()->process(\$input, \%vars, \$output) or die(
#		$self->library()->_template()->error()
#	);

	return $output;
}


=attribute collected_data

[% ss.name %] is true if data has been collected for this document, or
false if it still needs to collect data.  It's mainly used internally
by collect_data() to guard against redundant collection.

=cut

has collected_data => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

=method collect_data

[% ss.name %] prepares the document for rendering by performing all
prerequisite actions.  Data is collected and validated.  Intermediate
indexes are built.  And so on.

Returns nothing on success.  Returns a list of human-friend.y error
messages on failure.

=cut

sub collect_data {
	my ($self, $errors) = @_;

	return if $self->collected_data();
	$self->collected_data(1);

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

	# Documentation for attributes and methods is attached to those
	# entities in memory, so the code entities must be indexed first.
	# This group must go last, however, so that references within their
	# documentation are indexed in advance.

	$self->index_code_attributes($errors);
	$self->index_code_methods($errors);

	# Simple things go first.

	$self->parse_doc_references($errors);

	# NOTE - Skips are special.
	$self->extract_doc_commands($errors, 'extract_doc_skip');

	# Code inclusions are "use" and "require", as well as Moose things
	# that may pull code in from elsewhere.

	$self->index_code_inclusions($errors);

	# NOTE - Attributes and methods are special.  It's okay for them to
	# be processed specially.

	# Once explicit code and documentation are associated, we can see
	# which remain undocumented and need to inherit documentation or
	# have boilerplate docs written.

	# TODO - For each undocumented attribute or method, try to find
	# documentation up the inheritance or role chain until we reach the
	# entity's implementation.

	#$self->inherit_documentation();

	#$self->validate_doc_references();

	# TODO - Load and parse all cross referenced modules.  We need
	# enough data to set xrefs, import inclusions, and import examples
	# from other, possibly non-Moose distributions.

	# TODO - Validate whether all cross referenced modules exist, within
	# and outside the current distribution.
}

###
### Collect data from the documentation, but leave markers behind.
###

=method index_doc_commands

[% ss.name %] iterates the Pod::Elemental::Element::Generic::Command
elements of a module's documentation.  Its single parameter is the
name of a $self method to call for each command node.  Those methods
should parse the command, enter appropriate data into the object.

=cut

sub index_doc_commands {
	my ($self, $errors, $method) = @_;

	my $doc = $self->_elemental()->children();

	my $i = @$doc;
	NODE: while ($i--) {
		my $node = $doc->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		my $result = $self->$method($errors, $doc->[$i]);

		# TODO - Better check for $result being an entity?
		next NODE unless $result and ref $result;

		# The return value is an entity.
		# Append the following text to its documentation.
		# Remove the text; we only need the command to mark the location.

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


=method parse_doc_references

[% ss.name %] examines each Pod::Elemental command node.  Ones that
are listed as known reference commands, such as "=abstract" or
"=example", are parsed and recorded by their appropriate
Pod::Plexus::Reference classes.

All other Pod::Elemental commands are ignored.

=cut

sub parse_doc_references {
	my ($self, $errors, $method) = @_;

	my $doc = $self->_elemental()->children();

	foreach my $pod_priority (sort { $b <=> $a } keys %pod_prio_commands) {
		my $available_commands = $pod_prio_commands{$pod_priority};

		my $i = @$doc;
		NODE: while ($i--) {
			my $node = $doc->[$i];

			next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');
			next NODE unless exists $available_commands->{$node->{command}};

			my $reference_class = $available_commands->{$node->{command}};
			my $reference = $reference_class->new_from_elemental_command(
				$self->library(), $self, $errors, $node
			);

			# One or more errors occurred.
			# It's up to the reference class to record errors.
			return unless $reference;

			$self->_add_reference($reference);

			# The reference class wishes to consume documentation.
			if ($reference->includes_text()) {
				my $j = $i + 2;
				TEXT: while ($j < @$doc) {
					unless (
						$doc->[$j]->isa('Pod::Elemental::Element::Generic::Command')
					) {
						$reference->push_documentation( splice(@$doc, $j, 1) );
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

					$reference->push_documentation( splice(@$doc, $j, 1) );
				}

				$reference->cleanup_documentation();
			}

			elsif ($reference->discards_text()) {
				my $j = $i + 2;
				TEXT: while ($j < @$doc) {
					unless (
						$doc->[$j]->isa('Pod::Elemental::Element::Generic::Command')
					) {
						splice(@$doc, $j, 1);
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

					splice(@$doc, $j, 1);
				}
			}

			# Discard the command, if necessary.  Done last.  Everything is
			# based on offsets, so we work from the higher offsets backward to
			# avoid renumbering everything.

			if ($reference->discards_command()) {
				splice(
					@$doc, $i, 1,
					Pod::Elemental::Element::Generic::Command->new(
						command => 'pod',
						content => "\n",
					),
					Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
				);
			}
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


=macro extract_doc_command_callback

This method is a callback to extract_doc_command().  That other method
is a generic iterator to walk through the Pod::Elemental document in
memory and remove nodes that have been successfully parsed.  Node
removal is triggered by callbacks, such as [% ss.name %] returning a
true value.

As with all [% mode.name %] parsers, only the Pod::Elemental data in
memory is affected.  The source on disk is untouched.

=cut


=method extract_doc_skip

[% ss.name %] examines a single Pod::Elemental command node.  If it's
a "=skip" directive, its data is entered into the [% mod.name %]
object, and [% ss.name %] returns true.  False is returned for all
other nodes.

=demacro extract_doc_command_callback

=cut

sub extract_doc_skip {
	my ($self, $errors, $node) = @_;

	return unless $node->{command} eq 'skip';

	my ($entity_type, $entity_name) = (
		$node->{content} =~ /^\s* (attribute|method) \s+ (\S.*?) \s*$/x
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

	my $meta = $self->mop_class();
	ATTRIBUTE: foreach my $name ($meta->get_attribute_list()) {
		next ATTRIBUTE if $self->is_skippable_attribute($name);

		my $attribute = $meta->get_attribute($name);

		# TODO - How to report the places where it's defined?  Can it be?
		if ($self->_has_attribute($name)) {
			push @$errors, (
				"Attribute $name defined more than once.  Second one is" .
				" at " . $self->pathname() . " line $attribute->{start_line}"
			);
			next ATTRIBUTE;
		}

		my $entity = Pod::Plexus::Entity::Attribute->new(
			mop_entity => $attribute,
			name       => $name,
		);

		$self->_add_attribute($name, $entity);
	}
}


=method index_code_methods

Find and register all methods known by Class::MOP to exist in the
class being documented.

This is a helper method called by index().

=cut

sub index_code_methods {
	my ($self, $errors) = @_;

	my $meta = $self->mop_class();
	METHOD: foreach my $name ($meta->get_method_list()) {
		next METHOD if $self->is_skippable_method($name);

		my $method = $meta->get_method($name);

		# Assume constants aren't documented.
		# TODO - Need a better way to identify them, eh?
		next METHOD if $name =~ /^[A-Z0-9_]+$/;

		# TODO - How to report the places where it's defined?  Can it be?
		if ($self->_has_method($name)) {
			push @$errors, (
				"Method $name defined more than once.  Second one is" .
				" at " . $self->pathname() . " line $method->{start_line}"
			);
			next METHOD;
		}

		my $entity = Pod::Plexus::Entity::Method->new(
			mop_entity => $method,
			name       => $name,
		);

		$self->_add_method($name, $entity);
	}
}


=method index_code_inclusions

Find and register all modules known by Class::MOP to contribute to
this class.  Base classes and roles are prime examples of the modules
collected by [% ss.name %].

=cut

sub index_code_inclusions {
	my $self = shift();

	# TODO - This uses PPI, but it might be cleaner to use Moose.

	my $ppi = $self->_ppi();

	my $inclusions = $ppi->find(
		sub {
			$_[1]->isa('PPI::Statement::Include') or (
				$_[1]->isa('PPI::Statement') and
				$_[1]->child(0)->isa('PPI::Token::Word') and
				$_[1]->child(0)->content() eq 'extends'
			)
		}
	);

	return unless $inclusions and @$inclusions;

	foreach (@$inclusions) {
		my $type = $_->child(0)->content();

		# Remove "type".
		my @children = $_->children();
		splice(@children, 0, 1);

		my @stuff;
		foreach (@children) {
			if ($_->isa('PPI::Token::Word')) {
				push @stuff, $_->content();
				next;
			}

			if ($_->isa('PPI::Structure::List')) {
				push @stuff, map { $_->string() } @{ $_->find('PPI::Token::Quote') };
				next;
			}

			if ($_->isa('PPI::Token::QuoteLike::Words')) {
				push @stuff, $_->literal();
				next;
			}

			if ($_->isa('PPI::Token::Quote')) {
				push @stuff, $_->string();
				next;
			}

			# Ignore the others.
			next;
		}

		given ($type) {
			when ('use') {
				$self->add_import($_, 1) foreach @stuff;
			}
			when ('require') {
				# TODO - Do we care about this?  Probably not if we're
				# introspecting with Moose, since by the time we get here the
				# "no" things should have been removed.
				#
				# TODO - I guess it only matters if there's an import().
			}
			when ('no') {
				# TODO - Do we care about this?  Probably not if we're
				# introspecting with Moose, since by the time we get here the
				# "no" things should have been removed.
			}
			when ('extends') {
				$self->add_base_class($_, 1) foreach @stuff;
			}
			when ('with') {
				$self->add_role($_, 1) foreach @stuff;
			}
			default {
				die "odd type '$type'";
			}
		}
	}
}

###
### Dereference documentation references.
###

=method dereference

[% ss.name %] acquires or generates documentation from references.
Each satisfied reference is considered to be resolved, or
"dereferenced".

[% ss.name %] will dereference documentation recursively, if needed.
Previous indexing passes should have guaranteed that all referenced
modules exist, but the presence of necessary symbols will be
determined during this call.

=cut

sub dereference {
	my ($self, $errors) = @_;
	my $library = $self->library();

	# Dereference explicit references.

	REFERENCE: foreach my $reference ($self->_get_references()) {
		next REFERENCE if $reference->is_documented();
		$reference->dereference($library, $self, $errors);
	}

	return if @$errors;

	$_->cleanup_documentation() foreach $self->_get_references();

	# TODO - This is the only one we should have left.
	$self->expand_doc_commands($errors, 'expand_doc_simple');
	return if @$errors;
}


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

	die $self->package(), " doesn't define sub $sub_name" unless @$subs;
	die $self->package(), " defines too many subs $sub_name" if @$subs > 1;

	return $subs->[0]->content();
}


=method code

[% ss.name %] returns the code portion of the file represented by this
document.  This is used to render code examples by quoting entire
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


=method pod_section

[% ss.name %] returns a copy of the documentation for a specified POD
section, or undef if the section doesn't exist.

=cut

sub pod_section {
	my ($self, $section_name) = @_;

	my $closing_command;
	my @insert;

	SOURCE_NODE: foreach my $source_node (@{ $self->_elemental()->children() }) {

		unless (
			$source_node->isa('Pod::Elemental::Element::Generic::Command')
		) {
			push @insert, $source_node if $closing_command;
			next SOURCE_NODE;
		}

		if ($closing_command) {
			# TODO - What other conditions close an element?

			last SOURCE_NODE if (
				$source_node->{command} eq $closing_command or
				$source_node->{command} eq 'cut'
			);

			push @insert, $source_node;
			next SOURCE_NODE;
		}

		next unless $source_node->{content} =~ /^\Q$section_name\E/;

		$closing_command = $source_node->{command};
	}

	return dclone(\@insert);
}


###
### Expand documentation.
###

sub expand_doc_commands {
	my ($self, $errors, $method) = @_;

	my $doc = $self->_elemental()->children();

	for (1..10) {
		my $expansion_count = 0;

		my $i = @$doc;
		NODE: while ($i--) {
			my $node = $doc->[$i];

			next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

			my @result = $self->$method($errors, $node);
			next NODE unless @result;

			splice(@$doc, $i, 1, @result);

			++$expansion_count;
		}

		next if $expansion_count;

		# TODO - Kludge to prevent references from resolving to themselves
		# over and over again.

		FIXUP: foreach (@$doc) {
			next FIXUP unless $_->isa('Pod::Elemental::Element::Generic::Command');
			$_->{command} =~ s/^\((.*?)\)$/$1/;
		}

		return;
	}

	warn "Potential recursive expansion in ", $self->pathname();
}

sub expand_doc_simple {
	my ($self, $errors, $node) = @_;

	return unless exists $pod_commands{$node->{command}};
	my $reference_class = $pod_commands{$node->{command}};

	my $reference = $reference_class->expand($self, $errors, $node);
	return unless $reference;

	return @{$reference->documentation()};
}

###
### Debugging.
###

sub BUILD {
	warn "Absorbing ", shift()->pathname(), " ...\n";
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

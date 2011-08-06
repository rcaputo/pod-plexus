package Pod::Plexus::Document;

use Moose;
use PPI;
use Pod::Elemental;
use Devel::Symdump;
use Storable qw(dclone);

use Pod::Plexus::Entity::Method;
use Pod::Plexus::Entity::Attribute;

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
### Public data.
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

=attribute abstract

The [% ss.name %] attribute contains the abstract of the module being
documented.  It is populated by the "=abstract" directive.

=cut

has abstract => (
	is      => 'rw',
	isa     => 'Str',
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
		_add_attribute => 'set',
		_has_attribute => 'exists',
		_get_attribute => 'get',
		_get_attributes => 'values',
	},
);

=attribute methods

[% ss.name %] contains an hash of all identified methods in the class
being documented.  They are keyed on method name, and values are
Pod::Plexus::Entity::Method objects.

=cut

has methods => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Entity::Method]',
	traits   => [ 'Hash' ],
	handles => {
		_add_method => 'set',
		_has_method => 'exists',
		_get_method => 'get',
		_get_methods => 'values',
	},
);

=attribute mop_class

[% ss.name %] contains a Class::MOP::Class object that describes the
class being documented from Class::MOP's perspective.  It allows
Pod::Plexus to introspect the class and do many wonderful things with
it, such as inherit documentation from parent classes.

=cut

has mop_class => (
	is => 'rw',
	isa => 'Class::MOP::Class',
	lazy => 1,
	default => sub {
		my $self = shift();

		my $class_name = $self->package();
		return unless $class_name;

		# Must be loaded to be introspected.
		Class::MOP::load_class($class_name);
		return Class::MOP::Class->initialize($class_name);
	},
);

# TODO - Gathering or grouping documentation into topics.
# TODO - Gathering topics under higher level topics.
# TODO - Essentially outlining without building an explicit outline.

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
			meta        => 1,
			BUILDARGS   => 1,
			BUILDALL    => 1,
			DEMOLISHALL => 1,
			does        => 1,
			DOES        => 1,
			dump        => 1,
			can         => 1,
			VERSION     => 1,
			DESTROY     => 1,
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

### Cross references.

=attribute see_also

[% ss.name %] contains a hash of cross references defined by the
"=xref" directive.  The project wishes to also index implicit
references, but these haven't been defined yet.  Discussons welcome.

=cut

has see_also => (
	is      => 'rw',
	isa     => 'HashRef[Str]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_add_xref => 'set',
		_has_refs => 'count',
	},
);

### Cached rendered content?

=method code

Return the code portion of the file represented by this document.
Documentation is stripped away.  This is used to render code examples
by quoting entire modules.

=cut

sub code {
	my $self = shift();

	my $out = $self->_ppi()->clone();
	$out->prune('PPI::Statement::End');
	$out->prune('PPI::Statement::Data');
	$out->prune('PPI::Token::Pod');

	return $out->serialize();
}

=method sub

Return the code for a particular named subroutine or method in this
document.  Written so that code examples can be made by quoting
individual subroutines rather than entire modules.

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

	$self->library()->_template()->process(\$input, \%vars, \$output) or die(
		$self->library()->_template()->error()
	);

	return $output;
}

=method can_render

[% ss.name %] prepares the document for rendering by performing all
prerequisite actions.  Data is collected and validated.  Intermediate
indexes are built.  And so on.

Returns nothing on success.  Returns a list of human-friend.y error
messages on failure.

=cut

sub can_render {
	my $self = shift;

	my @errors;

	# Simple things go first.

	$self->extract_doc_commands(\@errors, 'extract_doc_skip');
	$self->extract_doc_commands(\@errors, 'extract_doc_abstract');

	# TODO - extract_doc_macro

	$self->index_code_attributes(\@errors);
	$self->index_code_methods(\@errors);

	#$self->index_code_inclusions(\@errors);

	$self->extract_doc_commands(\@errors, 'extract_doc_attribute_or_method');

#$self->inherit_documentation();
#$self->validate_doc_references();

#$self->index_cross_references();

	return @errors;
}

###
### Extract and remove data from documentation.
###

=method extract_doc_command

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

		# TODO - Generic means to remove an extracted directive from the
		# POD, closing up the hole that's left.  Trailing "=cut" must
		# remain if there's POD before the directive.  Otherwise it must
		# also be removed.
		#
		# TODO - For now, let's try replacing the directive with an empty
		# "=pod" command.  Maybe that will be a sufficient no-op.

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

=include extract_doc_command_callback

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

=method extract_doc_abstract

[% ss.name %] examines a single Pod::Elemental command node.  If it's
an "=abstract" directive, the abstract string is entered into the
[% mod.name %] object, and [% ss.name %] returns true.  False is
returned for all other nodes.

=include extract_doc_command_callback

=cut

sub extract_doc_abstract {
	my ($self, $errors, $node) = @_;

	return unless $node->{command} eq 'abstract';

	if (defined $self->abstract()) {
		push @$errors, (
			"More than one =abstract found in " . $self->package() .
			".  Using the first one."
		);
		return 1;
	}

	$self->abstract( $node->{content} =~ /^\s* (\S.*?) \s*$/x );
	return 1;
}

=method index_doc_attributes_and_methods

[% ss.name %] scans the documentation for the module being documented.
It extracts "=attribute" and "=method" directives and associates their
content with corresponding attributes and methods.

=cut

sub extract_doc_attribute_or_method {
	my ($self, $errors, $node) = @_;

	my $entity_type = $node->{command};
	return unless $entity_type eq 'attribute' or $entity_type eq 'method';

	my ($entity_name) = ($node->{content} =~ /^\s* (\S.*?) (?:\s|$)/x);

	my $has_method = "_has_$entity_type";
	unless ($self->$has_method($entity_name)) {
		push @$errors, (
			"'=$entity_type $entity_name' for non-existent $entity_type " .
			" at " . $self->pathname() . " line $node->{start_line}"
		);
		return;
	}

	my $get_method = "_get_$entity_type";
	my $entity = $self->$get_method($entity_name);

	return $entity;
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

	ATTRIBUTE: foreach ($self->mop_class()->get_all_attributes()) {
		my $name = $_->name();

		next ATTRIBUTE if $self->is_skippable_attribute($name);

		# TODO - How to report the places where it's defined?
		if ($self->_has_attribute($name)) {
			push @$errors, "Attribute $name defined more than once...";
			next ATTRIBUTE;
		}

		my $entity = Pod::Plexus::Entity::Attribute->new(
			mop_entity => $_,
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

	METHOD: foreach ($self->mop_class()->get_all_methods()) {
		my $name = $_->name();

		next METHOD if $self->is_skippable_method($name);

		# Assume constants aren't documented.
		# TODO - Need a better way to identify them, eh?
		next METHOD if $name =~ /^[A-Z0-9_]+$/;

		# TODO - How to report the places where it's defined?
		if ($self->_has_method($name)) {
			push @$errors, "Method $name defined more than once...";
			next METHOD;
		}

		my $entity = Pod::Plexus::Entity::Method->new(
			mop_entity => $_,
			name       => $name,
		);

		$self->_add_method($name, $entity);
	}
}

=method index_code_inclusions

Find and register all modules known by Class::MOP to contribute to
this class.  Base classes and roles are prime examples of the modules
collected by [% ss.name %].

This is a helper method called by index().

=cut


###
### TODO - These are older things that need cleaning up.
###

sub index_code_inclusions {
	my $self = shift();

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

	foreach (@{$inclusions || []}) {
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
				# TODO - We care if it's "use base".
			}
			when ('no') {
				# TODO - Do we care about this?
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

=method index_cross_references

[% ss.name %] collects cross references from the code and
documentation into the C<see_also> attribute.  These references will
populate a "SEE ALSO" section later.

=cut

sub index_cross_references {
	my $self = shift();

	my $doc = $self->_elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children()->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		if ($node->{command} eq 'xref') {
			my ($module) = ($node->{content} =~ /^\s* (\S.*?) \s*$/x);
			$self->_add_xref($module, 1);
			splice(@{$doc->children()}, $i, 1);
			next NODE;
		}
	}
}

=method dereference_mutables

[% ss.name %] attempts to replace C<=example> and C<=include>
references with the code and documentation to which they refer.  It
performs these replacements for local references first.  If all local
references resolve, it goes on to the foreign ones.

[% ss.name %] returns true if all references were successfully
resolved.  Otherwise, it returns false.  The caller uses these values
to determine whether another pass at them must be made.

=example Pod::Plexus::Library dereference

=cut

###
### Expansions?
###

sub dereference_mutables {
	my $self = shift();

	my @undefined = $self->dereference_remotes();
	return @undefined if @undefined;

	@undefined = $self->dereference_locals();
	return @undefined if @undefined;

	return;
}

=method dereference_immutables

[% ss.name %] expands things that don't rely upon the files that
contain them or the positions in which they occur.

=cut

sub dereference_immutables {
	my $self = shift();

	my $doc = $self->_elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children()->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		### "=copyright (years) (whom)" -> "=head1 COPYRIGHT AND LICENSE"
		### boilerplate.

		if ($node->{command} eq 'copyright') {
			my ($year, $whom) = ($node->{content} =~ /^\s*(\S+)\s+(.*?)\s*$/);

			splice(
				@{$doc->children()}, $i, 1,
				Pod::Elemental::Element::Generic::Command->new(
					command => "head1",
					content => "COPYRIGHT AND LICENSE\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						$self->package() . " is Copyright $year by $whom.\n" .
						"All rights are reserved.\n" .
						$self->package() .
						" is released under the same terms as Perl itself.\n"
					),
				),
			);

			next NODE;
		}

		# Index modules in the library that match a given regular
		# expression.  Dangerous, but we're all friends here, right?

		if ($node->{command} =~ /^index(\d*)/) {
			my $level = $1 || 2;

			(my $regexp = $node->{content} // "") =~ s/\s+//g;
			$regexp = "^" . $self->package() . "::" unless length $regexp;

			my @insert = (
				map {
					Pod::Elemental::Element::Generic::Command->new(
						command => "item",
						content => "*\n",
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
					Pod::Elemental::Element::Generic::Text->new(
						content => (
							"L<$_|$_> - " .
							$self->library()->package($_)->abstract()
						),
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
				}
				sort
				grep /$regexp/, $self->library()->get_module_names()
			);

			unless (@insert) {
				@insert = (
					Pod::Elemental::Element::Generic::Command->new(
						command => "item",
						content => "*\n",
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
					Pod::Elemental::Element::Generic::Text->new(
						content => "No modules match /$regexp/"
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
				);
			}

			splice( @{$doc->children()}, $i, 1, @insert );

			next NODE;
		}

		# "=example (spec)" -> code example inclusion.
		# Code examples include no documentation references, so go ahead.

		if ($node->{command} eq 'example') {
			my ($type, $module, $method) = $self->parse_example_spec($node);
			my @content = $self->get_code_content($type, $module, $method);
			splice( @{$doc->children()}, $i, 1, @content );
			next NODE;
		}

		### "=abstract (text)" -> "=head1 NAME\n\n(module) - (text)\n\n".

		if ($node->{command} eq 'abstract') {
			splice(
				@{$doc->children()}, $i, 1,
				Pod::Elemental::Element::Generic::Command->new(
					command => "head1",
					content => "NAME\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Text->new(
					content => $self->package() . " - " . $self->abstract()
				),
			);
			next NODE;
		}

	}
}

=method dereference_locals

[% ss.name %] dereferences local references only.  It returns true if
there are no local references, or they all resolved.  It returns false
if any local references remain unresolved.

=cut

sub dereference_locals {
	my $self = shift();

	my @unresolved_names;

	my $doc = $self->_elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children()->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		# "=include (spec)" -> documentation inclusion

		if ($node->{command} eq 'include') {
			my ($type, $module, $section) = $self->parse_include_spec($node);
			next NODE unless $type & SCOPE_LOCAL;

			# If the remote thing is fully resolved, then pull it in.
			# TODO - Meanwhile, pretend it failed.

			push @unresolved_names, "=$node->{command} $node->{content}";
			next NODE;
		}
	}

	return @unresolved_names;
}

=method dereference_remotes

[% ss.name %] dereferences remote references only.  It returns true if
there are no remote references, or they all resolved.  It returns
false if any remote references remain unresolved.

=cut

sub dereference_remotes {
	my $self = shift();

	my @unresolved_names;

	my $doc = $self->_elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children()->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		### "=include MODULE SECTION" -> documentation copied from source.
		#
		# TODO - Need to ensure the full rendering of source material
		# before inserting it here.

		if ($node->{command} eq 'include') {
			my ($module_name, $section) = split(/\s+/, $node->{content}, 2);

			# TODO - How do we check whether the remote section is defined?

			my $source_module = $self->library()->get_module($module_name);
			unless ($source_module) {
				push @unresolved_names, "=$module_name $section";
				next NODE;
			}

			my $source_doc = $source_module->_elemental();

			my $closing_command;
			my @insert;

			SOURCE_NODE: foreach my $source_node (@{ $source_doc->children() }) {

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

				next unless $source_node->{content} =~ /^\Q$section\E/;

				$closing_command = $source_node->{command};
			}

			unless (@insert) {
				push @unresolved_names, "=$module_name $section";
				next NODE;
			}

			# Trim blanks around a section of Pod::Elemental nodes.
			# TODO - Make a helper method.
			shift @insert while (
				@insert and $insert[0]->isa('Pod::Elemental::Element::Generic::Blank')
			);
			pop @insert while (
				@insert and $insert[-1]->isa('Pod::Elemental::Element::Generic::Blank')
			);

			splice( @{$doc->children()}, $i, 1, @insert );

			next NODE;
		}
	}

	return @unresolved_names;
}

=method inherit_documentation

[% ss.name %] finds documentation for attributes and methods that
aren't already documented in their own classes.

Methods may be automatically documented as accessors or mutators of
same- or ancestor-class attributes.

Methods and attributes implemented in ancestors will inherit
documentation from those ancestors or roles if they aren't documented
in the subclass or consumer.

=cut

sub inherit_documentation {
	my $self = shift();

	# Look to the ancestors for attributes that aren't documented here.
	# TODO - Is it better to walk up the family tree?

	# TODO - The definition_context of modified attributes (+name) is
	# the subclass, not the parent class.  We most certainly have to
	# talk back up the family tree in that case.

	ATTRIBUTE: foreach my $attribute ($self->_get_attributes()) {

		next ATTRIBUTE if $attribute->is_documented();
		next ATTRIBUTE if $attribute->private();
		next ATTRIBUTE if $self->is_skippable_attribute( $attribute->name() );

		my $impl_definition = $attribute->mop_entity()->definition_context();
		if ($attribute->name() eq 'mop_entity') {
			use YAML; die YAML::Dump($attribute->mop_entity());
		}
		next ATTRIBUTE unless $impl_definition;

		my $impl_module_name = $impl_definition->{package};
		next ATTRIBUTE unless (
			defined $impl_module_name and length $impl_module_name
		);

		my $impl_module = $self->library()->get_document($impl_module_name);
		next ATTRIBUTE unless $impl_module;

		my $impl = $impl_module->_get_attribute($attribute->name());
		next ATTRIBUTE unless $impl;

		next ATTRIBUTE unless $impl->is_documented();

		$attribute->push_documentation(dclone($_)) foreach (
			@{ $impl->documentation() }
		);

		# Inherit any necessary documentation.

		my %accessors;
		$accessors{$_} = 1 foreach (
			map { $attribute->mop_entity()->$_() // () }
			qw(
				builder initializer accessor get_read_method get_write_method clearer
			)
		);

		METHOD: foreach my $method_name (keys %accessors) {

			my $method = $impl_module->_get_method($method_name);

			next METHOD unless defined $method;
			next METHOD if $method->is_documented();
			next METHOD if $method->private();
			next METHOD if $self->is_skippable_method( $method_name );

			$method->push_documentation(
				Pod::Elemental::Element::Generic::Command->new(
					command => 'method',
					content => $method_name,
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						'[% ss.name %] is an (accessor? mutator? TODO) ' .
						'provided by ' . $attribute->name() . ".\n"
					)
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
			);
		}
	}

	# Make boilerplate documentation for needy accessors and mutators.
	# Yes, it's a separate foreach() loop.  Not as efficient, but
	# potentially more refactorable.

	ATTRIBUTE: foreach my $attribute ($self->_get_attributes()) {
		my %accessors;
		$accessors{$_} = 1 foreach (
			map { $attribute->mop_entity()->$_() // () }
			qw(
				builder initializer accessor get_read_method get_write_method clearer
			)
		);

		# TODO - It's not good enough for the "having" things.

		METHOD: foreach my $method_name (keys %accessors) {
			my $method = $self->_get_method($method_name);
			next unless defined $method;
			next METHOD if $method->is_documented();
			next METHOD if $method->private();
			next METHOD if $self->is_skippable_method( $method_name );

			$method->push_documentation(
				Pod::Elemental::Element::Generic::Command->new(
					command => 'method',
					content => $method_name,
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						'[% ss.name %] is an (accessor? mutator? TODO) ' .
						'provided by ' . $attribute->name() . ".\n"
					)
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
			);
		}
	}

	# Look to the ancestors for methods that aren't documented here.
	# TODO - Is it better to walk up the family tree?

	METHOD: foreach my $method ($self->_get_methods()) {
		next METHOD if $method->is_documented();
		next METHOD if $method->private();
		next METHOD if $self->is_skippable_method( $method->name() );

		# Boilerplate documentation if this method is provided by an
		# attribute in the same class.

		if ($method->name() eq 'new') {
			$method->push_documentation(
				Pod::Elemental::Element::Generic::Command->new(
					command => 'method',
					content => $method->name(),
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						"[% ss.name %] constructs one [% mod.package %] object.\n" .
						"See L</PUBLIC ATTRIBUTES> for constructor options.\n"
					),
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
			);

			next METHOD;
		}

		next METHOD unless exists $method->mop_entity()->{definition_context};

		my $impl_definition = $method->mop_entity()->{definition_context};
		next METHOD unless $impl_definition;

		my $impl_module_name = $impl_definition->{package};
		next METHOD unless (
			defined $impl_module_name and length $impl_module_name
		);

		my $impl_module = $self->library()->get_document($impl_module_name);
		next METHOD unless $impl_module;

		my $impl = $impl_module->_get_method($method->name());
		next METHOD unless $impl;

		next METHOD unless $impl->is_documented();

		$method->push_documentation(dclone($_)) foreach (
			@{ $impl->documentation() }
		);

		$method->push_documentation(
			Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
			Pod::Elemental::Element::Generic::Text->new(
				content => (
					"This method and its documentation are inherited from " .
					"L<$impl_module_name/" . $method->name() . ">."
				),
			),
			Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
		);
	}
}

###
### Helpers.  Almost worth making them private.
###

=method parse_example_spec

[% ss.name %] parses the specification for examples.  It's used by the
"=example" directive to identify which code is being used as an
example.

=cut

sub parse_example_spec {
	my ($self, $node) = @_;

	return unless $node->{command} eq 'example';

	my (@args) = split(/[\s\/]+/, $node->{content});

	die "too many args for example" if @args > 2;
	die "not enough args for example" if @args < 1;

	# TODO - TYPE_FILE if the spec contains a "." or "/" to indicate a
	# path name.

	# "Module::method()" or "Module method()".

	if ($node->{content} =~ /^\s*(\S+)(?:\s+|::)(\w+)\(\)\s*$/) {
		my ($package, $method) = ($1, $2);
		return( $self->get_scope($package) | TYPE_SUB, $package, $method );
	}

	# Just "method()".

	if ($node->{content} =~ /^(\w+)\(\)$/) {
		my $package = $1;
		return( MOD_IMPLICIT | SCOPE_LOCAL | TYPE_SUB, $self->package(), $1 );
	}

	# Assuming just "Module".

	my ($package) = ($node->{content} =~ /\s*(\S.*?)\s*/);
	return( $self->get_scope($package) | TYPE_PACKAGE, $package, undef );
}

=method parse_include_spec

[% ss.name %] parses the specification for documentation inclusions.
It's used by the "=include" directive to identify which documentation
to include.

=cut

sub parse_include_spec {
	my ($self, $node) = @_;

	return unless $node->{command} eq 'include';

	if ($node->{content} =~ m!^\s* (\S.*?) \s* / \s* (\S.*?) \s*$!x) {
		my ($package, $section) = ($1, $2);
		return( $self->get_scope($package) | TYPE_SECTION, $package, $section );
	}

	if ($node->{content} =~ m!^\s* / \s* (\S.*?) \s*$!x) {
		return( SCOPE_LOCAL | TYPE_SECTION, $self->package(), $1 );
	}

	die(
		"Wrong inclusion syntax:\n",
		"=include $node->{content}\n",
	)
}

=method get_scope

[% ss.method %] is a helper method to determine whether a package is
local or remote.  A local package is the same as the module currently
being documented.  All the other modules are remote.

=cut

sub get_scope {
	my ($self, $package) = @_;
	return(
		MOD_EXPLICIT | (
			($package eq $self->package())
			? SCOPE_LOCAL
			: SCOPE_FOREIGN
		)
	);
}

=method validate_doc_references

[% ss.name %] checks whether every implemented attribute and method is
either documented, implicitly skipped by virtue of being a basic Moose
method, or explicitly skipped with a "=skip" directive.

Undocumented methods cause runtime errors.

=cut

sub validate_doc_references {
	my $self = shift();

	# While we're here, we can complain about undocumented things.

	my $failures = 0;

	ATTRIBUTE: foreach my $attribute ($self->_get_attributes()) {

		next ATTRIBUTE if $attribute->is_documented();
		next ATTRIBUTE if $attribute->private();
		next ATTRIBUTE if $self->is_skippable_attribute( $attribute->name() );

		warn(
			$self->package(), " attribute ", $attribute->name(),
			" is not documented\n"
		);

		$failures++;
	}

	METHOD: foreach my $method ($self->_get_methods()) {
		next METHOD if $method->is_documented();
		next METHOD if $method->private();
		next METHOD if $self->is_skippable_method( $method->name() );

		warn(
			$self->package(), " method ", $method->name(),
			" is not documented\n"
		);

		$failures++;
	}

	exit 1 if $failures;
}

=method get_code_content

[% ss.name %] returns the code content for a documentation reference,
such as "=example".  It takes three parameters, the type of reference,
the name of the module containing the code, and the name of the
method.  These come directly from parse_example_spec().

It returns a list of Pod::Elemental elements suitable for splicing
directly into the documentation.

=cut

sub get_code_content {
	my ($self, $type, $module, $method) = @_;

	my $content = $self->library()->get_document($module)->sub($method);

	# TODO - PerlTidy the code?
	# TODO - The following whitespace options are personal
	# preference.  Someone should patch them to be options.

	# Convert tab indents to fixed spaces for better typography.
	$content =~ s/\t/  /g;

	# Indent two spaces.  Remove leading and trailing blank lines.
	$content =~ s/\A(^\s*$)+//m;
	$content =~ s/(^\s*$)+\Z//m;
	$content =~ s/^/  /mg;

	my $link;
	if ($type & TYPE_PACKAGE) {
		# I hope it's not necessary to explain where it came from if it
		# contains a package statement.

		if ($content =~ /^\s*package/) {
			$link = "";
		}
		else {
			$link = "This is L<$module|$module>.\n\n";
		}
	}
	else {
		if ($type & SCOPE_LOCAL) {
			$link = "This is L<$method()|/$method>.\n\n";
		}
		else {
			$link = (
				"This is L<$module|$module> " .
				"sub L<$method()|$module/$method>.\n\n"
			);
		}
	}

	return(
		Pod::Elemental::Element::Generic::Text->new(
			content => $link . $content,
		),
		Pod::Elemental::Element::Generic::Blank->new(
			content => "\n",
		),
	);
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

=abstract Represent and render a single Pod::Plexus document.

=cut

# TODO - If $self->_has_xrefs() then render them into an existing SEE
# ALSO section.  If there isn't a SEE ALSO section, create one.
#
#		### "=xref (module)" -> "=item *\n\n(module) - (its abstract)"
#		#
#		# TODO - Collect them without rendering.  Add them to a SEE ALSO
#		# section.
#
#		if ($node->{command} eq 'xref') {
#			my $module = $node->{content};
#			$module =~ s/^\s+//;
#			$module =~ s/\s+$//;
#
#			splice(
#				@{$doc->children()}, $i, 1,
#				Pod::Elemental::Element::Generic::Command->new(
#					command => "item",
#					content => "*\n",
#				),
#				Pod::Elemental::Element::Generic::Blank->new(
#					content => "\n",
#				),
#				Pod::Elemental::Element::Generic::Text->new(
#					content => (
#						"L<$module|$module> - " .
#						$self->library()->package($module)->abstract()
#					),
#				),
#				Pod::Elemental::Element::Generic::Blank->new(
#					content => "\n",
#				),
#			);
#
#			next NODE;
#		}

# =example ModuleName
# =example method_name()
# =example ModuleName method_name()
#
# =include SECTION
# =include ModuleName/Section


#=attribute base_classes
#
#[% ss.name %] contains a set of parent classes of the class being
#documented.  index_inclusions() populates it by analyzing the module's
#source code for telltale statements.
#
#=method add_base_class CLASS_NAME
#
#[% ss.name %] adds a CLASS_NAME to this document's set of base
#classes.
#
#=cut
#
#has base_classes => (
#	is       => 'rw',
#	isa      => 'HashRef[Str]',
#	traits   => [ 'Hash' ],
#	handles  => {
#		_add_base_class => 'set',
#	},
#);
#
#sub add_base_class {
#	my ($self, $class_name) = @_;
#	$self->_add_base_class($class_name, 1);
#}
#
#=attribute roles
#
#[% ss.name %] contains a set of roles consumed by the class being
#documented.  index_inclusions() populates it by analyzing the module's
#source code for telltale statements.
#
#=method add_role ROLE_NAME
#
#[% ss.name %] adds ROLE_NAME to this documents set of consumed roles.
#
#=cut
#
#has roles => (
#	is       => 'rw',
#	isa      => 'HashRef[Str]',
#	traits   => [ 'Hash' ],
#	handles  => {
#		_add_role => 'set',
#	},
#);
#
#sub add_role {
#	my ($self, $role_name) = @_;
#	$self->_add_role($role_name, 1);
#}

### SKIPPABLE ATTRIBUTES

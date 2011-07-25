package Pod::Plexus::Document;

use Moose;
use PPI;
use Pod::Elemental;
use Devel::Symdump;

use Pod::Plexus::Entity::Method;
use Pod::Plexus::Entity::Attribute;

use feature 'switch';

use PPI::Lexer;
$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';

use constant {
	SCOPE_LOCAL    => 0x01,
	SCOPE_FOREIGN  => 0x02,

	TYPE_SUB       => 0x10,
	TYPE_PACKAGE   => 0x20,
	TYPE_SECTION   => 0x40,
};

has pathname => ( is => 'ro', isa => 'Str', required => 1 );

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

=attribute base_classes

[% ss.name %] contains a set of parent classes of the class being
documented.  index_inclusions() populates it by analyzing the module's
source code for telltale statements.

=method add_base_class CLASS_NAME

[% ss.name %] adds a CLASS_NAME to this document's set of base
classes.

=cut

has base_classes => (
	is       => 'rw',
	isa      => 'HashRef[Str]',
	traits   => [ 'Hash' ],
	handles  => {
		_add_base_class => 'set',
	},
);

sub add_base_class {
	my ($self, $class_name) = @_;
	$self->_add_base_class($class_name, 1);
}

=attribute roles

[% ss.name %] contains a set of roles consumed by the class being
documented.  index_inclusions() populates it by analyzing the module's
source code for telltale statements.

=method add_role ROLE_NAME

[% ss.name %] adds ROLE_NAME to this documents set of consumed roles.

=cut

has roles => (
	is       => 'rw',
	isa      => 'HashRef[Str]',
	traits   => [ 'Hash' ],
	handles  => {
		_add_role => 'set',
	},
);

sub add_role {
	my ($self, $role_name) = @_;
	$self->_add_role($role_name, 1);
}

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

has abstract => (
	is      => 'rw',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my @abstracts;

		foreach my $node (@{ $self->_elemental()->children() }) {
			next unless $node->isa('Pod::Elemental::Element::Generic::Command');
			next unless $node->{command} eq 'abstract';
			push @abstracts, $node->content();
		}

		die "No =abstract found in ", $self->package(), "\n" unless @abstracts;

		if (@abstracts > 1) {
			warn(
				"More than one =abstract found in ", $self->package(),
				".  Using the first one."
			);
		}

		return $abstracts[0];
	},
);

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

has extends => (
	is => 'ro',
);

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

# TODO - How about a "hoist" directive that pulls in documentation
# from the sources of inherited symbols?
#
has skip_attributes => (
	is      => 'rw',
	isa     => 'HashRef',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		is_skippable_attribute => 'exists',
		_skip_attribute => 'set',
	}
);

sub skip_attribute {
	my $self = shift();
	$self->_skip_attribute($_, 1) foreach @_;
}

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
		_skip_method => 'set',
	}
);

sub skip_method {
	my $self = shift();
	$self->_skip_method($_, 1) foreach @_;
}

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
		_add_xref => 'set'
	},
);

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

### End public accessors!

sub BUILD {
	warn "Absorbing ", shift()->pathname(), " ...\n";
}

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

	$self->_template()->process(\$input, \%vars, \$output) or die(
		$self->_template()->error()
	);

	return $output;
}

sub elementaldump {
	my $self = shift();
	use YAML;
	print YAML::Dump($self->_elemental());
	exit;
}

sub ppidump {
	my $self = shift();
	use PPI::Dumper;
	my $d = PPI::Dumper->new( $self->_ppi() );
	$d->print();
	exit;
}

=method index

Index the nameable aspects of the file being documented, including POD
section types and names, method names, attribute names, and the names
of parent and child classes.

=cut

sub index {
	my $self = shift();

	$self->index_skips();

	$self->index_code_attributes();
	$self->index_code_inclusions();
	$self->index_code_methods();

	$self->index_doc_abstract();
	$self->index_doc_attributes_and_methods();
	$self->index_cross_references();
}

=method index_skips

[% ss.name %] indexes "=skip" directives.

=cut

sub index_skips {
	my $self = shift();

	my $doc = $self->_elemental()->children();

	my $i = @$doc;
	NODE: while ($i--) {

		my $node = $doc->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');
		next NODE unless $node->{command} eq 'skip';

		my ($entity_type, $entity_name) = (
			$node->{content} =~ /^\s* (attribute|method) \s+ (\S.*?) \s*$/x
		);

		my $skip_method = "skip_$entity_type";
		$self->$skip_method($entity_name);

		splice(
			@$doc, $i, 1,
			Pod::Elemental::Element::Generic::Command->new(
				command => 'pod',
				content => '',
			),
			Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
		);
	}
}

=method index_code_attributes

Find and register all attributes known by Class::MOP to exist.

This is a helper method called by index().

=cut

sub index_code_attributes {
	my $self = shift();

	foreach ($self->mop_class()->get_all_attributes()) {
		my $name = $_->name();
		die "$name used more than once" if $self->_has_attribute($name);

		my $entity = Pod::Plexus::Entity::Attribute->new(
			mop_entity => $_,
			name       => $name,
		);

		$self->_add_attribute($name, $entity);
	}
}

=method index_code_inclusions

Find and register all modules known by Class::MOP to contribute to
this class.  Base classes and roles are prime examples of the modules
collected by [% ss.name %].

This is a helper method called by index().

=cut

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

=method index_code_methods

Find and register all methods known by Class::MOP to exist in the
class being documented.

This is a helper method called by index().

=cut

sub index_code_methods {
	my $self = shift();

	foreach ($self->mop_class()->get_all_methods()) {
		my $name = $_->name();

		next if $self->is_skippable_method($name);

		die "$name used more than once" if $self->_has_method($name);

		my $entity = Pod::Plexus::Entity::Method->new(
			mop_entity => $_,
			name       => $name,
		);

		$self->_add_method($name, $entity);
	}
}

sub index_doc_attributes_and_methods {
	my $self = shift();

	my $doc = $self->_elemental()->children();

	my $i = @$doc;
	NODE: while ($i--) {

		my $node = $doc->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		my $entity_type = $node->{command};
		next NODE unless $entity_type eq 'attribute' or $entity_type eq 'method';

		my ($entity_name) = ($node->{content} =~ /^\s* (\S.*?) (?:\s|$)/x);

		my $has_method = "_has_$entity_type";
		my $get_method = "_get_$entity_type";

		unless ($self->$has_method($entity_name)) {
			die(
				"'=$entity_type $entity_name' for non-existent $entity_type ",
				" at ", $self->pathname(), " line $node->{start_line}\n"
			);
		}

		my $entity = $self->$get_method($entity_name);

		$entity->push_documentation(
			splice(
				@$doc, $i, 1,
				Pod::Elemental::Element::Generic::Command->new(
					command => 'pod',
					content => '',
				),
				Pod::Elemental::Element::Generic::Blank->new( content => "\n" ),
			)
		);

		while ($i < @$doc) {
			unless ($doc->[$i]->isa('Pod::Elemental::Element::Generic::Command')) {
				$entity->push_documentation( splice(@$doc, $i, 1) );
				next;
			}

			if (
				$doc->[$i]->{command} eq 'cut' or
				$doc->[$i]->{command} eq 'attribute' or
				$doc->[$i]->{command} eq 'method' or
				$doc->[$i]->{command} eq 'xref' or
				$doc->[$i]->{command} =~ /^head/
			) {
				last;
			}

			$entity->push_documentation( splice(@$doc, $i, 1) );
		}
	}

	# While we're here, we can complain about undocumented things.

	my $failures = 0;

	ATTRIBUTE: foreach my $attribute ($self->_get_attributes()) {
		my %accessors;
		$accessors{$_} = 1 foreach (
			grep { defined }
			map { $attribute->mop_entity()->$_() }
			qw(
				builder initializer accessor get_read_method get_write_method clearer
			)
		);

		foreach my $method_name (keys %accessors) {
			my $method = $self->_get_method($method_name);
			next if $method->is_documented();

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

		unless ($attribute->is_documented()) {
			next ATTRIBUTE if $self->is_skippable_attribute( $attribute->name() );
			next ATTRIBUTE if $attribute->private();

			warn(
				$self->package(), " attribute ", $attribute->name(),
				" is not documented\n"
			);

			$failures++;
		}

	}

	METHOD: foreach my $method ($self->_get_methods()) {
		unless ($method->is_documented()) {
			next METHOD if $method->private();

			# Default documentation for new().

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

			warn(
				$self->package(), " method ", $method->name(),
				" is not documented\n"
			);

			$failures++;
		}
	}

	exit 1 if $failures;
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

=method index_doc_abstract

[% ss.name %] collects the document's "=abstract" string for
cross-reference purposes and eventual rendering.

=cut

sub index_doc_abstract {
	my $self = shift();

	my $doc = $self->_elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children()->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		if ($node->{command} eq 'abstract') {
			$self->abstract( $node->{content} =~ /^\s* (\S.*?) \s*$/x );
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

sub dereference_mutables {
	my $self = shift();

	return(
		$self->dereference_remotes() &&
		$self->dereference_locals() &&
		1
	);
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
	}
}


=method dereference_locals

[% ss.name %] dereferences local references only.  It returns true if
there are no local references, or they all resolved.  It returns false
if any local references remain unresolved.

=cut

sub dereference_locals {
	my $self = shift();

	my $needs_work = 0;

	my $doc = $self->_elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children()->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		# "=example (spec)" -> code example inclusion.

		if ($node->{command} eq 'example') {
			my ($type, $module, $method) = $self->parse_example_spec($node);
			next NODE unless $type & SCOPE_LOCAL;

			# If the remote thing is fully resolved, then pull it in.
			# TODO
			next NODE;
		}

		# "=include (spec)" -> documentation inclusion

		if ($node->{command} eq 'include') {
			my ($type, $module, $section) = $self->parse_include_spec($node);
			next NODE unless $type & SCOPE_LOCAL;

			# If the remote thing is fully resolved, then pull it in.
			# TODO
			next NODE;
		}
	}

	return 0;
}

sub dereference_remotes {
	my $self = shift();

	warn "not yet... dereference_remotes()";

	return 0;
}

sub parse_example_spec {
	my ($self, $node) = @_;

	return unless $node->{command} eq 'example';

	my (@args) = split(/[\s\/]+/, $node->{content});

	die "too many args for example" if @args > 2;
	die "not enough args for example" if @args < 1;

	# "Module::method()" or "Module method()".

	if ($node->{content} =~ /^\s*(\S+)(?:\s+|::)(\w+)\(\)\s*$/) {
		my ($package, $method) = ($1, $2);
		return( $self->get_scope($package) | TYPE_SUB, $package, $method );
	}

	# Just "method()".

	if ($node->{content} =~ /^(\w+)\(\)$/) {
		my $package = $1;
		return( SCOPE_LOCAL | TYPE_SUB, $self->package(), $1 );
	}

	# Assuming just "Module".

	my ($package) = ($node->{content} =~ /\s*(\S.*?)\s*/);
	return( $self->get_scope($package) | TYPE_PACKAGE, $package, undef );
}

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

#sub expand_commands {
#	my $self = shift();
#
#	my $doc = $self->_elemental();
#
#	my $i = @{ $doc->children() };
#	NODE: while ($i--) {
#
#		my $node = $doc->children()->[$i];
#
#		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');
#
#		### "=example (spec)" -> code example sourced from (spec).
#
#		if ($node->{command} eq 'example') {
#			my (@args) = split(/\s+/, $node->{content});
#
#			die "too many args for example" if @args > 2;
#			die "not enough args for example" if @args < 1;
#
#			my ($link, $content);
#			if (@args == 2) {
#				$link = (
#					"This is L<$args[0]|$args[0]> " .
#					"sub L<$args[1]()|$args[0]/$args[1]>.\n\n"
#				);
#
#				$content = $self->library()->get_document($args[0])->sub($args[1]);
#			}
#			elsif ($args[0] =~ /:/) {
#				# TODO - We're trying to omit the "This is" link if the
#				# content includes an obvious package name.  There may be a
#				# better way to do this, via PPI for example.
#
#				$content = $self->library()->get_module($args[0])->code();
#				if ($content =~ /^\s*package/) {
#					$link = "";
#				}
#				else {
#					$link = "This is L<$args[0]|$args[0]>.\n\n";
#				}
#			}
#			elsif ($args[0] =~ /[\/.]/) {
#				# Reference by path doesn't omit the "This is" link.
#				# It's intended to be used with executable programs.
#
#				$content = $self->library()->_get_document($args[0])->code();
#				$link = "This is L<$args[0]|$args[0]>.\n\n";
#			}
#			else {
#				$link = "This is L<$args[0]()|/$args[0]>.\n\n";
#				$content = $self->sub($args[0]);
#			}
#
#			# TODO - PerlTidy the code?
#			# TODO - The following whitespace options are personal
#			# preference.  Someone should patch them to be options.
#
#			# Indent two spaces.  Remove leading and trailing blank lines.
#			$content =~ s/\A(^\s*$)+//m;
#			$content =~ s/(^\s*$)+\Z//m;
#			$content =~ s/^/  /mg;
#
#			# Convert tab indents to fixed spaces for better typography.
#			$content =~ s/\t/  /g;
#
#			splice(
#				@{$doc->children()}, $i, 1,
#				Pod::Elemental::Element::Generic::Text->new(
#					content => $link . $content,
#				),
#				Pod::Elemental::Element::Generic::Blank->new(
#					content => "\n",
#				),
#			);
#
#			next NODE;
#		}
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
#
#		### "=abstract (text)" -> "=head1 NAME\n\n(module) - (text)\n\n".
#
#		if ($node->{command} eq 'abstract') {
#			splice(
#				@{$doc->children()}, $i, 1,
#				Pod::Elemental::Element::Generic::Command->new(
#					command => "head1",
#					content => "NAME\n",
#				),
#				Pod::Elemental::Element::Generic::Blank->new(
#					content => "\n",
#				),
#				Pod::Elemental::Element::Generic::Text->new(
#					content => $self->package() . " - " . $self->abstract()
#				),
#			);
#			next NODE;
#		}
#
#		### "=copyright (years) (whom)" -> "=head1 COPYRIGHT AND LICENSE"
#		### boilerplate.
#
#		if ($node->{command} eq 'copyright') {
#			my ($year, $whom) = ($node->{content} =~ /^\s*(\S+)\s+(.*?)\s*$/);
#
#			splice(
#				@{$doc->children()}, $i, 1,
#				Pod::Elemental::Element::Generic::Command->new(
#					command => "head1",
#					content => "COPYRIGHT AND LICENSE\n",
#				),
#				Pod::Elemental::Element::Generic::Blank->new(
#					content => "\n",
#				),
#				Pod::Elemental::Element::Generic::Text->new(
#					content => (
#						$self->package() . " is Copyright $year by $whom.\n" .
#						"All rights are reserved.\n" .
#						$self->package() .
#						" is released under the same terms as Perl itself.\n"
#					),
#				),
#			);
#
#			next NODE;
#		}
#
#		# Index modules in the library that match a given regular
#		# expression.  Dangerous, but we're all friends here, right?
#
#		if ($node->{command} =~ /^index(\d*)/) {
#			my $level = $1 || 2;
#
#			(my $regexp = $node->{content} // "") =~ s/\s+//g;
#			$regexp = "^" . $self->package() . "::" unless length $regexp;
#
#			my @insert = (
#				map {
#					Pod::Elemental::Element::Generic::Command->new(
#						command => "item",
#						content => "*\n",
#					),
#					Pod::Elemental::Element::Generic::Blank->new(
#						content => "\n",
#					),
#					Pod::Elemental::Element::Generic::Text->new(
#						content => (
#							"L<$_|$_> - " .
#							$self->library()->package($_)->abstract()
#						),
#					),
#					Pod::Elemental::Element::Generic::Blank->new(
#						content => "\n",
#					),
#				}
#				sort
#				grep /$regexp/, $self->library()->get_module_names()
#			);
#
#			unless (@insert) {
#				@insert = (
#					Pod::Elemental::Element::Generic::Command->new(
#						command => "item",
#						content => "*\n",
#					),
#					Pod::Elemental::Element::Generic::Blank->new(
#						content => "\n",
#					),
#					Pod::Elemental::Element::Generic::Text->new(
#						content => "No modules match /$regexp/"
#					),
#					Pod::Elemental::Element::Generic::Blank->new(
#						content => "\n",
#					),
#				);
#			}
#
#			splice( @{$doc->children()}, $i, 1, @insert );
#
#			next NODE;
#		}
#
#		### "=include MODULE SECTION" -> documentation copied from source.
#		#
#		# TODO - Need to ensure the full rendering of source material
#		# before inserting it here.
#
#		if ($node->{command} eq 'include') {
#			my @args = split(/\s+/, $node->{content});
#
#			die "too many args for include" if @args > 2;
#			die "not enough args for include" if @args < 2;
#
#			my ($module_name, $section) = @args;
#
#			my $source_module = $self->library()->get_module($module_name);
#
#			die "unknown module $module_name in include" unless $source_module;
#
#			my $source_doc = $source_module->_elemental();
#
#			my $closing_command;
#			my @insert;
#
#			SOURCE_NODE: foreach my $source_node (@{ $source_doc->children() }) {
#
#				unless (
#					$source_node->isa('Pod::Elemental::Element::Generic::Command')
#				) {
#					push @insert, $source_node if $closing_command;
#					next SOURCE_NODE;
#				}
#
#				if ($closing_command) {
#					# TODO - What other conditions close an element?
#
#					last SOURCE_NODE if (
#						$source_node->{command} eq $closing_command or
#						$source_node->{command} eq 'cut'
#					);
#
#					push @insert, $source_node;
#					next SOURCE_NODE;
#				}
#
#				next unless $source_node->{content} =~ /^\Q$section\E/;
#
#				$closing_command = $source_node->{command};
#			}
#
#			die "Couldn't find =insert $module_name $section" unless @insert;
#
#			# Trim blanks around a section of Pod::Elemental nodes.
#			# TODO - Make a helper method.
#			shift @insert while (
#				@insert and $insert[0]->isa('Pod::Elemental::Element::Generic::Blank')
#			);
#			pop @insert while (
#				@insert and $insert[-1]->isa('Pod::Elemental::Element::Generic::Blank')
#			);
#
#			splice( @{$doc->children()}, $i, 1, @insert );
#
#			next NODE;
#		}
#	}
#}

sub get_scope {
	my ($self, $package) = @_;
	return(
		($package eq $self->package())
		? SCOPE_LOCAL
		: SCOPE_FOREIGN
	);
}

no Moose;

1;

__END__

=pod

=abstract Represent and render a single Pod::Plexus document.

=cut

# =example ModuleName
# =example method_name()
# =example ModuleName method_name()
#
# =include SECTION
# =include ModuleName/Section

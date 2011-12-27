package Pod::Plexus::Module::Code;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Module::Subset';

use PPI;
use Scalar::Util qw(weaken);

use PPI::Lexer;
$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';

use Pod::Plexus::Code::Method;
use Pod::Plexus::Code::Attribute;


=abstract Represent and process the code portion of a Perl module.

=cut


=head1 SYNOPSIS

Instantiation.

=example Pod::Plexus::Module attribute code

Usage is generally through Pod::Plexus::Module.

=cut


=head1 DESCRIPTION

[% m.package %] provides Pod::Plexus with access to modules' source
code.  For example, it extracts the code for attributes and methods
for '=example' sections.

[% m.package %] is tightly coupled to Pod::Plexus::Module.  For all
intents and purposes, Pod::Plexus::Module embodies the public API that
includes [% m.package %] features.

=cut


has '+module' => (
	handles => [ qw( pathname ) ],
);


=attribute _ppi

"[% s.name %]" contains a PPI::Document representing the module being
documented.  [% m.package %] uses this to find source code for
inclusion in the documentation, examine the module's implementation
for documentation cues, and so on.

=cut

has _ppi => (
	is      => 'ro',
	isa     => 'PPI::Document',
	lazy    => 1,
	default => sub { PPI::Document->new( shift()->pathname() ) },
);


=attribute package

[% m.package %]'s "[% s.name %]" attribute contains the module's first
(and hopefully main) package name.  It's main use is in template
expansion, via the "[Z<>% m.package %]" expression.

Note that "[Z<>% m %]" references the [% m.package %] object for the
module being documented.  All the modules and methods implemented here
are also available in the documentation itself.

Because of the way "[% s.name %]" works, it's probably better for
every package to exist in its own module.  Undefined things may occur
if a module contains more than one package.

Contributions are welcome to improve this situation.

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


=attribute meta_module

"[% s.name %]" contains a Class::MOP::Module object that describes the
module being documented.  This allows Pod::Plexus to inspect the
module and do many wonderful things with it, such as inherit
documentation from parent classes and consumed roles.

By default, "[% s.name %]" also ensures that the documented class is
loaded and the meta-Class::MOP::Class is initialized.  These are
prerequisites for "[% s.name %]" being valid.

=cut

has meta_module => (
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
		return $x;
	},
);


=method dump

[% s.name %]() prints the PPI document resulting from the parsed
module's source.  It's been useful for developing parsers like the
ones in get_method_source().

=cut

sub dump {
	my $self = shift();
	use PPI::Dumper;
	my $d = PPI::Dumper->new( $self->_ppi() );
	$d->print();
	exit;
}


=boilerplate example_uses_it

"=example" uses this to hoist code into the documentation.

=cut


=method get_method_source

[% s.name %](METHOD_NAME) returns the source code that implements a
method in this module.

=include boilerplate example_uses_it

=cut

sub get_method_source {
	my ($self, $method_name) = @_;

	my $subs = $self->_ppi()->find(
		sub {
			return 0 unless $_[1]->isa('PPI::Statement::Sub');
			return 0 unless defined $_[1]->name();
			return 0 unless $_[1]->name() eq $method_name;
			return 1;
		}
	);

	return unless $subs and @$subs;
	return $subs->[0]->content();
}


=method get_module_source

[% s.name %](MODULE_PACKAGE) returns the source code for an entire
module.  Use with care, as this can be quite long---often much longer
than is appropriate for a documentation illustration.

=include boilerplate example_uses_it

=cut

sub get_module {
	my $self = shift();

	my $out = $self->_ppi()->clone();
	$out->prune('PPI::Statement::End');
	$out->prune('PPI::Statement::Data');
	$out->prune('PPI::Token::Pod');

	return $out->serialize();
}


=method get_attribute_source

[% s.name %](ATTRIBUTE_NAME) returns the source code that defines an
attribute in this module.

=include boilerplate example_uses_it

=cut

sub get_attribute_source {
	my ($self, $attribute_name) = @_;

	my $attributes = $self->_ppi()->find(
		sub {
			return 0 unless $_[1]->isa('PPI::Statement');

			my @children = $_[1]->children();

			return 0 unless @children > 3;

			return 0 unless (
				$children[0]->isa('PPI::Token::Word') and
				$children[0]->literal() eq 'has'
			);

			return 0 unless $children[1]->isa('PPI::Token::Whitespace');

			return 0 unless (
				$children[2]->content() =~ /^(['"]?)\+?$attribute_name\1$/
			);

			return 1;
		}
	);

	return unless $attributes and @$attributes;

	return $attributes->[0]->content();
}


=method add_matter_accessor

[% s.name %](ACCESSOR_NAME, MATTER_OBJECT) makes a documentation
MATTER_OBJECT accessible as a class method named ACCESSOR_NAME.

Pod::Plexus cheats a bit.  Rather than duplicate the inheritance tree
for a distribution, it injects accessors into classes and roles so
that Perl's inheritance does the work.

In the case of Moose roles, [% s.name %]() retroactively applies the
new accessor to all of the role's consumers.

=cut

sub add_matter_accessor {
	my ($self, $cache_name, $matter) = @_;

	my $meta = $self->meta_module();

	weaken $matter;
	my $cache_body = sub { return $matter };

	$meta->add_method($cache_name, $cache_body);

	if ($meta->can('consumers')) {
		my @consumers = $meta->consumers();
		CONSUMER: while (@consumers) {
			my $next_class = shift @consumers;

			my $next_meta  = $next_class->meta();
			next CONSUMER if $next_meta->has_method($cache_name);

			$next_meta->add_method($cache_name, $cache_body);

			push @consumers, $next_meta->consumers() if $next_meta->can('consumers');
		}
	}

	return;
}


=method find_matter

[% s.name %](CACHE_NAME) finds the documentation matter described by
CACHE_NAME within the module's code.  It assumes that
add_matter_accessor() was first called to associate the CACHE_NAME
with the module.

=cut

sub find_matter {
	my ($self, $cache_name) = @_;
	my $class_name = $self->meta_module()->name();
	return unless $class_name->can($cache_name);
	return $class_name->$cache_name();
}


sub validate {
	my $self = shift();

	# Do all attributes and methods have docs?

	warn "  TODO - validate()" if $self->verbose();

	return;
}


has _UNUSED_attributes => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Code::Attribute]',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		_UNUSED_add_attribute  => 'set',
		_UNUSED_has_attribute  => 'exists',
		_UNUSED_get_attribute  => 'get',
		_UNUSED_get_attributes => 'values',
	},
);


has _UNUSED_methods => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Code::Method]',
	traits  => [ 'Hash' ],
	default => sub { { } },
	handles => {
		_UNUSED_add_method  => 'set',
		_UNUSED_has_method  => 'exists',
		_UNUSED_get_method  => 'get',
		_UNUSED_get_methods => 'values',
	},
);


sub _UNUSED_cache_all_attributes {
	my ($self, $errors) = @_;

	$self->verbose() and warn(
		"  caching ", $self->package(), " code attributes...\n"
	);

	my $meta = $self->meta_module();

	# get_attribute_list() returns the name of all attributes defined in
	# this class.

	ATTRIBUTE: foreach my $attribute_name ($meta->get_attribute_list()) {
		#next ATTRIBUTE if $self->is_skippable_attribute($attribute_name);

		$self->verbose() and warn(
			"    caching ", $self->package(), " attribute $attribute_name\n"
		);

		my $attribute = $meta->get_attribute($attribute_name);

		# TODO - How to report the places where it's defined?  Can it be?
		if ($self->_has_attribute($attribute_name)) {
			push @$errors, (
				"Attribute $attribute_name defined more than once.  Second one is" .
				" at " . $self->pathname() .
				" line " . $attribute->start_line()
			);
			next ATTRIBUTE;
		}

		my $entity = Pod::Plexus::Code::Attribute->new(
			meta_entity => $attribute,
			name        => $attribute_name,
		);

		$self->_add_attribute($attribute_name, $entity);

		# Scratchpad the attribute's definition information for
		# inheritance checking later.

		my $thunk_name = Pod::Plexus::Matter->calc_cache_name(
			'attribute', $attribute_name
		);

		my $thunk_entity = $entity;
		weaken $thunk_entity;
		my $thunk_body = sub { return $thunk_entity };

		$meta->add_method($thunk_name, $thunk_body);

		if ($meta->can('consumers')) {
			my @consumers = $meta->consumers();
			while (@consumers) {
				my $next_class = shift @consumers;
				$next_class->meta()->add_method($thunk_name, $thunk_body);
				push @consumers, $next_class->meta()->consumers() if (
					$next_class->meta()->can('consumers')
				);
			}
		}

		# Add associated methods.

		if (defined(my $handles = $attribute->handles())) {
			$handles = { map { $_ => $_ } @$handles } if ref($handles) eq 'ARRAY';
			foreach my $method (values %$handles) {
				#my $entity = $self->cache_one_method($errors, $method);

				# TODO - Indicate the entity came from an attribute.
			}
		}

		if ($attribute->has_read_method()) {
			my $reader_name = $attribute->get_read_method();
			my $reader_body = $meta->get_method($reader_name);

			$self->cache_one_method($errors, $reader_body);

			if ($attribute->has_write_method()) {
				my $writer_name = $attribute->get_write_method();

				if ($reader_name ne $writer_name) {
					my $writer_body = $meta->get_method($writer_name);
					$self->cache_one_method($errors, $writer_body);
				}
			}
		}
	}
}


sub _UNUSED_cache_all_methods {
	my ($self, $errors) = @_;

	$self->verbose() and warn(
		"  caching ", $self->package(), " code methods...\n"
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

	my $meta = $self->meta_module();

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
		$self->cache_one_method($errors, $method);
	}
}


sub _UNUSED_cache_one_method {
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

	$self->verbose() and warn(
		"    caching ", $self->package(), " method $method_name\n"
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

1;

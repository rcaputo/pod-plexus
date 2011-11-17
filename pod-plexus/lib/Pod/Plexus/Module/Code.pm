package Pod::Plexus::Module::Code;

use Moose;
use PPI;
use Scalar::Util qw(weaken);

use PPI::Lexer;
$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';


use Pod::Plexus::Code::Method;
use Pod::Plexus::Code::Attribute;


has module => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Module',
	required => 1,
	weak_ref => 1,
	handles  => [
		qw(
			pathname
		),
	],
);


has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	weak_ref => 1,
	lazy     => 1,
	default  => sub { shift()->module()->distribution() },
);


=attribute _ppi

[% s.name %] contains a PPI::Document representing parsed module
being documented.  [% m.package %] uses this to find source code to
include in the documentation, examine the module's implementation for
documentation clues, and so on.

=cut

has _ppi => (
	is      => 'ro',
	isa     => 'PPI::Document',
	lazy    => 1,
	default => sub { PPI::Document->new( shift()->pathname() ) },
);


has verbose => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);


=attribute package

[% s.name %] contains the module's main package name.  Its main use
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


=attribute meta_entity

[% s.name %] contains a meta-object that describes the class being
documented from Class::MOP's perspective.  It allows Pod::Plexus to
introspect the class and do many wonderful things with it, such as
inherit documentation from parent classes.

As of this writing however, it's beyond the author's ability to
reliable inherit attribute and method documentation from higher up the
class and role chain.  Hopefully someone with better Meta and MOP
chops can step up.

=cut

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
		return $x;
	},
);


=attribute attributes

[% s.name %] contains an hash of all identified attributes in the
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

[% s.name %] contains an hash of all identified methods in the class
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


=method dump

[% s.name %] is a debugging helper method to print the PPI document
for the class being documented, in PPI::Dumper format.

=cut

sub dump {
	my $self = shift();
	use PPI::Dumper;
	my $d = PPI::Dumper->new( $self->_ppi() );
	$d->print();
	exit;
}


=method cache_attributes

Find and register all attributes known by Class::MOP to exist.

=cut

sub cache_all_attributes {
	my ($self, $errors) = @_;

	$self->verbose() and warn(
		"  caching ", $self->package(), " code attributes...\n"
	);

	my $meta = $self->meta_entity();

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

		my $thunk_name = "-pod-plexus-code-attribute-$attribute_name-";
		my $thunk_entity = $entity;
		weaken $thunk_entity;
		$meta->add_method($thunk_name, sub { return $thunk_entity });

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


=method cache_all_methods

Find and register all methods known by Class::MOP to exist in the
class being documented.

=cut

sub cache_all_methods {
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
		$self->cache_one_method($errors, $method);
	}
}


sub cache_one_method {
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


sub validate_docs {
	my $self = shift();

	warn "  TODO - validate_docs()";

	return;
}


=method get_sub

[% s.name %] returns the code for a particular named subroutine or
method in the class being documented.  This is used to render code
examples from single subroutines.

=cut

sub get_sub {
	my ($self, $sub_name) = @_;

	my $subs = $self->_ppi()->find(
		sub {
			return 0 unless $_[1]->isa('PPI::Statement::Sub');
			return 0 unless defined $_[1]->name();
			return 0 unless $_[1]->name() eq $sub_name;
			return 1;
		}
	);

	return unless $subs and @$subs;
	return $subs->[0]->content();
}


=method get_module

[% s.name %] returns the code portion of the file represented by this
module.  This is used to render code examples by quoting entire
modules.

=cut

sub get_module {
	my $self = shift();

	my $out = $self->_ppi()->clone();
	$out->prune('PPI::Statement::End');
	$out->prune('PPI::Statement::Data');
	$out->prune('PPI::Token::Pod');

	return $out->serialize();
}


sub get_attribute {
	my ($self, $attribute_name) = @_;

	my $attributes = $self->_ppi()->find(
		sub {
			return 0 unless $_[1]->isa('PPI::Statement');

			my @elements = $_[1]->elements();

			return 0 unless @elements > 3;

			return 0 unless (
				$elements[0]->isa('PPI::Token::Word') and
				$elements[0]->literal() eq 'has'
			);

			return 0 unless $elements[1]->isa('PPI::Token::Whitespace');

			return 0 unless (
				$elements[2]->isa('PPI::Token::Word') and
				$elements[2]->literal() eq $attribute_name
			);

			return 1;
		}
	);

	return unless $attributes and @$attributes;

	return $attributes->[0]->content();
}


sub register_matter {
	my ($self, $matter) = @_;

	my $type = ref($matter);
	$type =~ s/^Pod::Plexus::Matter:://;
	$type =~ s/:+.*//;

	weaken $matter;

	$self->meta_entity()->add_method(
		"-pod-plexus-matter-${type}-" . $matter->name() . "-",
		sub { $matter }
	);

	undef;
}


1;

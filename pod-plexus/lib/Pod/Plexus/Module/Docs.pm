package Pod::Plexus::Module::Docs;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Module::Subset';

use Pod::Elemental;

use Pod::Plexus::Util::PodElemental qw(
	generic_command
	blank_line
	text_paragraph
	cut_paragraph
	is_blank_paragraph
);

use Pod::Plexus::Matter::abstract;
use Pod::Plexus::Matter::method;
use Pod::Plexus::Matter::attribute;
use Pod::Plexus::Matter::include;


=abstract Represent and process the documentation portion of a Perl module.

=cut


=head1 SYNOPSIS

Instantiation.

=example Pod::Plexus::Module attribute docs

Usage is generally through Pod::Plexus::Module.

=example Pod::Plexus::Module method cache_structure

=cut


=head1 DESCRIPTION

[% m.package %] parses, manages and renders documentation matter on
behalf of Pod::Plexus::Module, to which it's tightly coupled.  For all
intents and purposes, Pod::Plexus::Module embodies the public API that
includes [% m.package %] features.

=cut


has '+module' => (
	handles  => {
		package         => 'package',
		get_meta_module => 'get_meta_module',
	},
);


=attribute _elemental

[% s.name %] contains a Pod::Elemental::Document representing the
parsed POD from the module being documented.  [% m.package %]
documents modules by inspecting and revising [% s.name %], among other
things.

=cut

has _elemental => (
	is      => 'ro',
	isa     => 'Pod::Elemental::Document',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return Pod::Elemental->read_file(
			$self->module()->pathname()
		);
	},
);


=method get_matter

[% s.name %](MATTER_TYPE, SYMBOL_NAME) returns a single documentation
matter object, found by the MATTER_TYPE and an optional SYMBOL_NAME.
The docmentation matter must be explicitly written in the module in
question.  Use find_matter() To find inherited documentation as well.

=cut

sub get_matter {
	my ($self, $type, $symbol) = @_;

	my $cache_name = Pod::Plexus::Matter->calc_cache_name($type, $symbol);

	return unless $self->_has_matter($cache_name);
	return $self->_get_matter($cache_name);
}


=method find_matter

[% s.name %](MATTER_TYPE, SYMBOL_NAME) returns a single documentation
matter object, found by the MATTER_TYPE and optional SYMBOL_NAME.
[% s.name %]() will walk a module's inheritance tree to find
documentation, unlike get_matter().

=cut

sub find_matter {
	my ($self, $type, $symbol) = @_;
	my $cache_name = Pod::Plexus::Matter->calc_cache_name($type, $symbol);
	return $self->module()->find_matter($cache_name);
}


=method add_matter

[% s.name %](MATTER_OBJECT) inserts a MATTER_OBJECT into the
documentation for an object.  This is used to register explicitly
written documentation, as well as to inject inherited and generated
documentation at runtime.

=cut

sub add_matter {
	my ($self, $matter_object) = @_;

	my $cache_name = $matter_object->cache_name();
	return if $self->_has_matter($cache_name);

	$self->_really_add_matter($cache_name, $matter_object);
	$self->module()->add_matter_accessor($cache_name, $matter_object);
}


=attribute matter

"[% s.name %]" contains a hash table of Pod::Plexus::Matter objects
that have been added to the module using add_matter().

=cut

has matter => (
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Matter]',
	default => sub { { } },
	traits  => [ 'Hash' ],
	handles => {
		_really_add_matter => 'set',
		_has_matter        => 'exists',
		_get_matter        => 'get',
		_get_all_matter    => 'values',
	},
);


=inherits Pod::Plexus::Cli attribute blame

=cut

has blame => (
	is       => 'rw',
	isa      => 'Bool',
	required => 1,
);


=method cache_all_matter

[% s.name %] scans a module's documentation for recognizable
Pod::Elemental command nodes.  Every supported Pod::Elemental command
is replaced by a Pod::Plexus::Matter subclass named for it.  For
example, "=method" commands become Pod::Plexus::Matter::method
objects.  They will be rendered as POD as needed.

All other Pod::Elemental commands are left alone in the Pod::Elemental
document.

=example method cache_all_matter

=cut

sub cache_all_matter {
	my $self = shift();

	# TODO - This is almost identical to cache_plexus_directives().
	# The two methods should be refactored.

	my @errors;
	my $docs = $self->_elemental()->children();

	my $i = @$docs;
	ELEMENT: while ($i--) {
		my $element      = $docs->[$i];
		my $matter_class = $self->_element_to_matter_class($element);
		next ELEMENT unless $matter_class;

		# The method name is a lie.  We cache all matter that isn't
		# directives.

		next ELEMENT if $matter_class->isa('Pod::Plexus::Matter::Directive');

		push(
			@errors,
			$self->_create_matter_object($matter_class, $docs, $i, $element)
		);
	}

	return @errors;
}


=method abstract

[% s.name %]() returns the module's abstract, defined by the
"=abstract" command.

=cut

sub abstract {
	my $self = shift();
	my $abstract = $self->get_matter('abstract');
	confess "No abstract defined for ", $self->package(), "\n" unless $abstract;
	return $abstract->abstract();
}


=method skips_attribute

[% s.name %](ATTRIBUTE_NAME) returns a Boolean value indicating
whether an attribute should not be processed.  These attributes are
defined with "=skip attribute ATTRIBUTE_NAME" commands.

=cut

sub skips_attribute {
	my ($self, $name) = @_;
	my $skip = $self->get_matter('skip::attribute');
	return defined $skip;
}


=method skips_method

[% s.name %](METHOD_NAME) returns a Boolean value indicating whether a
method should not be processed.  These methods are defined with "=skip
method METHOD_NAME" commands.

=cut

sub skips_method {
	my ($self, $name) = @_;
	my $skip = $self->get_matter('skip::method');
	return defined $skip;
}


=method flatten_methods

[% s.name %]() is the mechanism where inherited method documentation
is flattened into a subclass' documentation.  Boilerplate
documentation for undocumented, public, un-skipped methods is
generated here, too.

=cut

sub flatten_methods {
	my $self = shift();

	my @errors;
	my $meta_class = $self->get_meta_module();

	my @methods;
	if ($meta_class->can('get_all_methods')) {
		@methods = $meta_class->get_all_methods();
	}
	else {
		@methods = (
			map { $meta_class->get_method($_) }
			$meta_class->get_method_list()
		);
	}

	METHOD: foreach my $meta_method (@methods) {
		my $method_name = $meta_method->name();

		# Skip internal methods.
		next METHOD if $method_name =~ /^__pod_plexus_/;

		# Skip methods upon request.
		next METHOD if $self->skips_method($method_name);

		# Skip if documented.
		my $pod_plexus_name = Pod::Plexus::Matter->calc_cache_name(
			'method', $method_name
		);
		next METHOD if $meta_class->get_method($pod_plexus_name);

		# Inherit it.
		my $doc_method = $meta_class->find_method_by_name($pod_plexus_name);
		if ($doc_method) {
			my $ancestor_package = $doc_method->package_name();
			push @errors, $self->_generate_documentation(
				generic_command(
					"inherits", "$ancestor_package method $method_name\n"
				),
				blank_line(),
				cut_paragraph(),
			);
			next METHOD;
		}

		# Nothing to inherit.  How about we document that it's not
		# documented?

		# But not if it's private.
		next METHOD if $method_name =~ /^_/;

		push @errors, $self->_generate_documentation(
			generic_command("method", $method_name . "\n"),
			blank_line(),
			text_paragraph("[% s.name %] is not yet documented.\n"),
			blank_line(),
			cut_paragraph(),
		);

		next METHOD;
	}

	return @errors;
}


=method flatten_attributes

[% s.name %]() is the mechanism where inherited attribute
documentation is flattened into a subclass's documentation.
Boilerplate documentation for undocumented, public, un-skipped
attributes is generated here, too.

=cut

sub flatten_attributes {
	my $self = shift();

	my @errors;
	my $meta_class = $self->get_meta_module();

	my @attributes;
	if ($meta_class->can('get_all_attributes')) {
		@attributes = $meta_class->get_all_attributes();
	}
	else {
		@attributes = (
			map { $meta_class->get_attribute($_) }
			$meta_class->get_attribute_list()
		);
	}

	ATTRIBUTE: foreach my $meta_attribute (@attributes) {
		my $attribute_name = $meta_attribute->name();

		# Skip if documented.  Yes, this calls get_method() here.
		my $pod_plexus_name = Pod::Plexus::Matter->calc_cache_name(
			'attribute', $attribute_name
		);
		next ATTRIBUTE if $meta_class->get_method($pod_plexus_name);

		# Inherit it.
		my $doc_method = $meta_class->find_method_by_name($pod_plexus_name);
		if ($doc_method) {
			my $ancestor_package = $doc_method->package_name();
			push @errors, $self->_generate_documentation(
				generic_command(
					"inherits", "$ancestor_package attribute $attribute_name\n"
				),
				blank_line(),
				cut_paragraph(),
			);
			next ATTRIBUTE;
		}

		# Nothing to inherit.  How about we document that it's not
		# documented?

		# But not if it's private.
		next ATTRIBUTE if $attribute_name =~ /^_/;

		# TODO - We can glean a lot about this attribute from
		# Moose::Meta::Attribute and Class::MOP::Attribute.

		push @errors, $self->_generate_documentation(
			generic_command("attribute", $attribute_name . "\n"),
			blank_line(),
			text_paragraph("Attribute [% s.name %] is not yet documented.\n"),
			blank_line(),
			cut_paragraph(),
		);

		next ATTRIBUTE;
	}

	return @errors;

	return;
}


sub _generate_documentation {
	my ($self, @paragraphs) = @_;

	my $docs = $self->_elemental()->children();

	push @$docs, blank_line() unless @$docs and is_blank_paragraph($docs->[-1]);

	my $docs_index = @$docs;
	push @$docs, @paragraphs;

	return $self->_cache_matter_section($docs, $docs_index);
}


sub _element_to_matter_class {
	my ($self, $element) = @_;

	return unless $element->isa('Pod::Elemental::Element::Generic::Command');

	my $command = $element->command();

	my $matter_class = "Pod::Plexus::Matter::$command";
	my $doc_file  = "$matter_class.pm";
	$doc_file =~ s/::/\//g;

	eval { require $doc_file };
	if ($@) {
		return if $@ =~ /^Can't locate/;
		confess "Can't cache matter section $matter_class ((($@)))";
	}

	return $matter_class;
}


sub _create_matter_object {
	my ($self, $matter_class, $docs, $docs_index, $element) = @_;

	my $matter_object = eval {
		$matter_class->new_from_element(
			module     => $self->module(),
			verbose    => $self->verbose(),
			blame      => $self->blame(),
			docs       => $docs,
			docs_index => $docs_index,
			element    => $element,
		)
	};

	if ($@) {
		die $@ unless ref($@) eq 'ARRAY';
		return @{$@};
	}

	$docs->[$docs_index] = $matter_object;
	$self->add_matter($matter_object);

	return;
}


sub _cache_matter_section {
	my ($self, $docs, $docs_index) = @_;

	my $element      = $docs->[$docs_index];
	my $matter_class = $self->_element_to_matter_class($element);
	return unless $matter_class;

	my @errors = $self->_create_matter_object(
		$matter_class, $docs, $docs_index, $element
	);

	return @errors if @errors;

	return;
}


=method validate

[% s.name %]() is a stub method for the future.  It's the point where
Pod::Plexus verifies that all documentation corresponds to something
significant in the distribution.

=cut

sub validate {
	my $self = shift();

	my @errors;

	# Module must have an abstract.
	# TODO - This isn't quite right because abstract() will confess
	my $abstract = $self->abstract();
	unless (defined $abstract and length $abstract) {
		push @errors,  $self->package() . ' needs an =abstract';
	}

	my $synopsis = $self->get_matter('head1', 'SYNOPSIS');
	unless (defined $synopsis and $synopsis =~ /\S/) {
		push @errors,  $self->package() . ' needs =head1 SYNOPSIS';
	}

	my $description = $self->get_matter('head1', 'DESCRIPTION');
	unless (defined $description and $description =~ /\S/) {
		push @errors, $self->package() . ' needs =head1 DESCRIPTION';
	}

	# TODO - Do all =attribute and =method have code?

	return @errors;
}


=method render_as_pod

[% s.name %]() generates and returns a single string containing the
entire POD for the class being documented.

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

		my $next_pod;
		if ($next->isa('Pod::Plexus::Matter')) {
			$next_pod = $next->as_pod_string($next);
		}
		else {
			$next_pod = $next->as_pod_string();
		}

		# Expand $next_pod as a template.

		# TODO - The PDO content is the template, and we supply the values
		# of common variables for things like [% s.name %].

		$rendered_documentation .= $next_pod;

		next NODE unless $next->can("children");

		my $sub_children = $next->children();
		unshift @queue, @$sub_children if @$sub_children;
	}

	return $rendered_documentation;
}


=method dump

[% s.name %]() is a debugging helper method to print the
Pod::Elemental data for the class being documented, in YAML format.

=cut

sub dump {
	my $self = shift();
	use YAML;
	print YAML::Dump($self->_elemental());
	exit;
}


=method cache_plexus_directives

[% s.name %]() finds Pod::Plexus parser directives in a module's
documentation, extracts them from the documentation (so they aren't
rendered), and caches their values for the rest of the parser to use.

[% s.name %]() must come before cache_all_matter() so that it can
affect the main parse phase.

=cut

sub cache_plexus_directives {
	my $self = shift();

	# TODO - This is almost identical to cache_all_matter().
	# The two methods should be refactored.

	my @errors;
	my $docs = $self->_elemental()->children();

	my $i = @$docs;
	ELEMENT: while ($i--) {
		my $element      = $docs->[$i];
		my $matter_class = $self->_element_to_matter_class($element);
		next ELEMENT unless $matter_class;

		# We only cache directives at this point.

		next ELEMENT unless $matter_class->isa('Pod::Plexus::Matter::Directive');

		push(
			@errors,
			$self->_create_matter_object($matter_class, $docs, $i, $element)
		);
	}

	return @errors;
}

1;

__END__

###
### POSSIBLY REUSABLE CODE HERE
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

			my $method_reference = Pod::Plexus::Matter::method->new(
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
			next if $self->_has_matter($method_reference->key());

			my @body = (
				blank_line(),
				text_paragraph(
					"$api_name() exposes $impl_name() from the attribute " .
					"\"$attribute_name\".\n"
				),
				blank_line(),
			);

			$method_reference->push_body(@body);
			$method_reference->push_documentation(@body);
			$method_reference->push_cut();

			$self->_add_reference($method_reference);

			push @{$self->_elemental()->children()}, (
				blank_line(),
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

	my $method_reference = Pod::Plexus::Matter::method->new(
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
	return if $self->_has_matter($method_reference->key());

	my @body = (
		blank_line(),
		text_paragraph(
			"$method_name() is $accessor_type " .
			"for the \"$attribute_name\" attribute.\n"
		),
		blank_line(),
	);

	$method_reference->push_body(@body);
	$method_reference->push_documentation(@body);
	$method_reference->push_cut();

	$self->_add_reference($method_reference);

	push @{$self->_elemental()->children()}, (
		blank_line(),
		$method_reference,
	);
}

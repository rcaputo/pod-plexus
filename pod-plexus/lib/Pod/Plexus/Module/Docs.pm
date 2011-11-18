package Pod::Plexus::Module::Docs;

use Moose;

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


has module => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Module',
	required => 1,
	weak_ref => 1,
	handles  => {
		package        => 'package',
		get_meta_class => 'get_meta_class',
	},
);


has distribution => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Distribution',
	weak_ref => 1,
	lazy     => 1,
	default  => sub { shift()->module()->distribution() },
);


=attribute _elemental

[% s.name %] contains a Pod::Elemental::Document representing the
parsed POD from the module being documented.  [% m.package %]
documents modules by inspecting and revising [% s.name %], among
other things.

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

[% s.name %] returns a single reference, keyed on the referent type,
and optional symbol name.

=cut

sub get_matter {
	my ($self, $type, $symbol) = @_;

	my $reference_key = Pod::Plexus::Matter->calc_key(
		$type, $symbol
	);

	return unless $self->_has_matter($reference_key);
	return $self->_get_matter($reference_key);
}


sub add_matter {
	my ($self, $docs) = @_;
	my $key = $docs->key();
	return if $self->_has_matter($key);
	$self->_really_add_matter($key, $docs);
	$self->module()->register_matter($docs);
}


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


has verbose => (
	is       => 'rw',
	isa      => 'Bool',
	required => 1,
);


=method cache_all_matter

[% s.name %] examines each Pod::Elemental command node for something
Pod::Plexus recognizes.  Every recognized Pod::Elemental command is
replaced by Pod::Plexus::Matter subclass named after it.  For example,
"=method" commands are replaced by Pod::Plexus::Matter::method
objects.  These objects will properly render to Pod::Elemental
elements and POD as needed.

All other Pod::Elemental commands are ignored.

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


sub abstract {
	my $self = shift();
	my $abstract = $self->get_matter('abstract');
	confess "No abstract defined for ", $self->package(), "\n" unless $abstract;
	return $abstract->abstract();
}


sub skips_attribute {
	my ($self, $name) = @_;
	my $skip = $self->get_matter('skip::attribute');
	return defined $skip;
}


sub skips_method {
	my ($self, $name) = @_;
	my $skip = $self->get_matter('skip::method');
	return defined $skip;
}


sub flatten_methods {
	my $self = shift();

	my @errors;
	my $meta_class = $self->get_meta_class();

	METHOD: foreach my $meta_method ($meta_class->get_all_methods()) {
		my $method_name = $meta_method->name();

		# Skip internal methods.
		next METHOD if $method_name =~ /^__pod_plexus_/;

		# Skip methods upon request.
		next METHOD if $self->skips_method($method_name);

		# Skip if documented.
		my $pod_plexus_name = "__pod_plexus_matter_method__$method_name\__";
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


sub flatten_attributes {
	my $self = shift();

	my @errors;
	my $meta_class = $self->get_meta_class();

	ATTRIBUTE: foreach my $meta_attribute ($meta_class->get_all_attributes()) {
		my $attribute_name = $meta_attribute->name();

		# Skip if documented.  Yes, this calls get_method() here.
		my $pod_plexus_name = "__pod_plexus_matter_attribute__$attribute_name\__";
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


sub document_accessors {
	my $self = shift();

	warn "  TODO - document_accessors()";

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

	my $matter_object = $matter_class->new_from_element(
		module     => $self->module(),
		verbose    => $self->verbose(),
		docs       => $docs,
		docs_index => $docs_index,
		element    => $element,
	);

	return @{$matter_object->errors()} if $matter_object->failed();

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


sub validate_code {
	my $self = shift();

	warn "  TODO - validate_code()";

	return;
}


=method render_as_pod

[% s.name %] generates and returns the POD for the class being
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

		my $next_pod;
		if ($next->isa('Pod::Plexus::Matter')) {
			$next_pod = $next->as_pod_string();
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

[% s.name %] is a debugging helper method to print the Pod::Elemental
data for the class being documented, in YAML format.

=cut

sub dump {
	my $self = shift();
	use YAML;
	print YAML::Dump($self->_elemental());
	exit;
}


=method cache_plexus_directives

Find Pod::Plexus parser directives in a module's documentation,
extract them from the documentation to be rendered, and cache their
values for the rest of the parser to use.

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

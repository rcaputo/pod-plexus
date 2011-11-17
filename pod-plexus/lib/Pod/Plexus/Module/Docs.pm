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


sub cache_all_matter {
	my $self = shift();

	# TODO - This has a lot in common with cache_plexus_directives().
	# Hoist commonalities into one or more helpers.

	my @errors;
	my $docs = $self->_elemental()->children();

	my $i = @$docs;
	ELEMENT: while ($i--) {
		my $element = $docs->[$i];
		next ELEMENT unless (
			$element->isa('Pod::Elemental::Element::Generic::Command')
		);

		my $command = $element->command();

		my $doc_class = "Pod::Plexus::Matter::$command";
		my $doc_file  = "$doc_class.pm";
		$doc_file =~ s/::/\//g;

		eval { require $doc_file };
		if ($@) {
			next ELEMENT if $@ =~ /^Can't locate/;
			die $@;
		}

		# The method name is a lie.  We cache all matter that isn't
		# directives.

		next ELEMENT if $doc_class->isa('Pod::Plexus::Matter::Directive');

		my $docs_object = $doc_class->new_from_element(
			module     => $self->module(),
			verbose    => $self->verbose(),
			docs       => $docs,
			docs_index => $i,
			element    => $element,
		);

		if ($docs_object->failed()) {
			push @errors, @{$docs_object->errors()};
			next ELEMENT;
		}

		$docs->[$i] = $docs_object;
		$self->add_matter($docs_object);
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
	my $docs = $self->_elemental()->children();

	my $meta_class = $self->get_meta_class();

	METHOD: foreach my $method ($meta_class->get_all_methods()) {
		my $method_name = $method->name();

		# Skip internal methods.
		next METHOD if $method_name =~ /^-pod-plexus-/;

		# And skip private methods, why not?
		next METHOD if $method_name =~ /^_/;

		# Skip if documented.
		my $pod_plexus_name = "-pod-plexus-matter-method-$method_name-";
		next METHOD if $meta_class->get_method($pod_plexus_name);

		# Inherit it.
		# TODO - Some of this code is redundant considering
		# cache_all_matter().  Refactor.
		my $doc_method = $meta_class->find_method_by_name($pod_plexus_name);
		if ($doc_method) {

			push @$docs, blank_line() unless (
				@$docs and is_blank_paragraph($docs->[-1])
			);

			my $ancestor_package = $doc_method->package_name();

			my $docs_index = @$docs;
			push @$docs, (
				generic_command("inherits", "$ancestor_package method $method_name"),
				blank_line(),
				cut_paragraph(),
			);

			my $docs_object = Pod::Plexus::Matter::inherits->new(
				module     => $self->module(),
				verbose    => $self->verbose(),
				docs       => $docs,
				docs_index => $docs_index,
				element    => $docs->[$docs_index],
			);

			if ($docs_object->failed()) {
				push @errors, @{$docs_object->errors()};
				next METHOD;
			}

			$docs->[$docs_index] = $docs_object;
			$self->add_matter($docs_object);

			next METHOD;
		}

		# Nothing to inherit.  How about we document that it's not
		# documented?

		# But not if it's private.
		next METHOD if $self->skips_method($method_name);

		push @$docs, blank_line() unless (
			@$docs and is_blank_paragraph($docs->[-1])
		);

		my $docs_index = @$docs;
		push @$docs, (
			generic_command("method", $method_name),
			blank_line(),
			text_paragraph("[% s.name %] is not yet documented.\n"),
			blank_line(),
			cut_paragraph(),
		);

		my $docs_object = Pod::Plexus::Matter::method->new(
			module     => $self->module(),
			verbose    => $self->verbose(),
			docs       => $docs,
			docs_index => $docs_index,
			element    => $docs->[$docs_index],
		);

		if ($docs_object->failed()) {
			push @errors, @{$docs_object->errors()};
			next METHOD;
		}

		$docs->[$docs_index] = $docs_object;
		$self->add_matter($docs_object);

		next METHOD;
	}

	return @errors;
}


sub flatten_attributes {
	my $self = shift();

	warn "  TODO - flatten_attributes()";

	return;
}


sub document_accessors {
	my $self = shift();

	warn "  TODO - document_accessors()";

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

	# TODO - This has a lot in common with cache_all_matter().
	# Hoist commonalities into one or more helpers.

	my @errors;
	my $docs = $self->_elemental()->children();

	my $i = @$docs;
	ELEMENT: while ($i--) {
		my $element = $docs->[$i];
		next ELEMENT unless (
			$element->isa('Pod::Elemental::Element::Generic::Command')
		);

		my $command = $element->command();

		my $doc_class = "Pod::Plexus::Matter::$command";

		my $doc_file  = "$doc_class.pm";
		$doc_file =~ s/::/\//g;

		eval { require $doc_file };
		if ($@) {
			next ELEMENT if $@ =~ /^Can't locate/;
			die $@;
		}

		# We only cache directives at this point.

		next ELEMENT unless $doc_class->isa('Pod::Plexus::Matter::Directive');

		my $docs_object = $doc_class->new_from_element(
			module     => $self->module(),
			verbose    => $self->verbose(),
			docs       => $docs,
			docs_index => $i,
			element    => $element,
		);

		if ($docs_object->failed()) {
			push @errors, @{$docs_object->errors()};
			next ELEMENT;
		}

		$docs->[$i] = $docs_object;

		$self->add_matter($docs_object);
	}

	return @errors;
}

1;

__END__


###
### Collect data from the documentation, but leave markers behind.
###

=method index_matter_references

[% s.name %] examines each Pod::Elemental command node.  Ones that
are listed as known reference commands, such as "=abstract" or
"=example", are parsed and recorded by their appropriate
Pod::Plexus::Matter classes.

All other Pod::Elemental commands are ignored.

=cut

sub index_matter_references {
	my ($self, $errors, $method) = @_;

	my $doc = $self->_elemental()->children();

	my $i = @$doc;
	NODE: while ($i--) {
		my $node = $doc->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');
		next NODE if exists $standard_pod_commands{$node->{command}};

		my @new_errors;

		my $doc_class = "Pod::Plexus::Matter::" . $node->{command};
		my $doc_file  = "$doc_class.pm";
		$doc_file =~ s/::/\//g;

		eval { require $doc_file };
		if ($@) {
			push @$errors, $@;
			next NODE;
		}

		my $reference = $doc_class->create(
			module       => $self,
			errors       => \@new_errors,
			distribution => $self->distribution(),
			node         => $node,
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
			$docs->module_package(),
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

		my $thunk_name = "-pod-plexus-documents-attribute-$attribute_name-";
		my $docs = eval { $this_class->$thunk_name() };

		# The attribute comes from an outside source.

		next ATTRIBUTE unless $docs;

		# The attribute is already documented by this class.

		next ATTRIBUTE if $docs->module() == $self;

		# The attribue is documented in a superclass.

		$self->_document_inherited_attribute(
			$this_docs,
			$this_class,
			$docs->module_package(),
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

	my $include_reference = Pod::Plexus::Matter::include->new(
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
		blank_line(),
		$include_reference,
		blank_line(),
		text_paragraph(
			"It is inherited from L<$class_name|$class_name/$method_name>.\n"
		),
		blank_line(),
		cut_paragraph(),
	);

	$method_reference->push_body(@body);
	$method_reference->push_documentation(@body);

	push @$this_docs, (
		blank_line(),
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

	my $attribute_reference = Pod::Plexus::Matter::attribute->new(
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

	my $include_reference = Pod::Plexus::Matter::include->new(
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
		blank_line(),
		$include_reference,
		blank_line(),
		text_paragraph(
			"It is inherited from L<$class_name|$class_name/$attribute_name>.\n"
		),
		blank_line(),
		cut_paragraph(),
	);

	$attribute_reference->push_body(@body);
	$attribute_reference->push_documentation(@body);

	push @$this_docs, (
		blank_line(),
		$attribute_reference,
	);
}

1;

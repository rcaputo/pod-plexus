package Pod::Plexus::Docs::Code::Attribute;

=abstract A reference to documentation for a class attribute.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command);


use constant POD_COMMAND  => 'attribute';


sub BUILD {
	my $self = shift();

	my ($module_name, $symbol_name) = $self->_parse_attribute_spec();

	return unless defined $module_name and length $module_name;

	$self->symbol($symbol_name);

	my $module = $self->distribution()->get_module($module_name);
	unless ($module) {
		push @{$self->errors()}, (
			"=attribute cannot find module $module_name" .
			" at " . $self->module_path() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	my $entity = $self->module()->_get_attribute($symbol_name);
	unless ($entity) {
		push @{$self->errors()}, (
			"Cannot find attribute $symbol_name in '=attribute'" .
			" at " . $self->module_path() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->push_documentation(
		generic_command("attribute", "$symbol_name\n"),
	);

	# Make a scratchpad entry in the class so we can find documentation.

	$self->module()->meta_entity()->add_method(
		"_pod_plexus_documents_attribute_$symbol_name\_" => sub { return $self },
	);
}


sub _parse_attribute_spec {
	my $self = shift();

	if ($self->node()->{content} =~ /^\s* (\S+) \s*$/x) {
		return($self->module_package(), $1);
	}

	push @{$self->errors()}, (
		"Wrong syntax: =attribute " . $self->node()->{content} .
		" at " . $self->module_path() .
		" line " . $self->node()->{start_line}
	);

	return;
}


no Moose;

1;

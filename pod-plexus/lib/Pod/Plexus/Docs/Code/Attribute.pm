package Pod::Plexus::Docs::Code::Attribute;

=abstract A reference to documentation for a class attribute.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Code';


use constant POD_COMMAND  => 'attribute';


sub BUILD {
	my $self = shift();

	my ($module_name, $symbol_name) = $self->_parse_attribute_spec();

	return unless defined $module_name and length $module_name;

	$self->symbol($symbol_name);

	my $module = $self->library()->get_document($module_name);
	unless ($module) {
		push @{$self->errors()}, (
			"=attribute cannot find module $module_name" .
			" at " . $self->document()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	my $entity = $self->document()->_get_attribute($symbol_name);
	unless ($entity) {
		push @{$self->errors()}, (
			"Cannot find attribute $symbol_name in '=attribute'" .
			" at " . $self->document()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->push_documentation(
		Pod::Elemental::Element::Generic::Command->new(
			command => "attribute",
			content => "$symbol_name\n",
		),
	);
}


sub _parse_attribute_spec {
	my $self = shift();

	if ($self->node()->{content} =~ /^\s* (\S+) \s*$/x) {
		return($self->document()->package(), $1);
	}

	push @{$self->errors()}, (
		"Wrong syntax: =attribute " . $self->node()->{content} .
		" at " . $self->document()->pathname() .
		" line " . $self->node()->{start_line}
	);

	return;
}


no Moose;

1;

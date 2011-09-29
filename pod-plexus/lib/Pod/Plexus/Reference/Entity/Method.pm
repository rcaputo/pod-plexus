package Pod::Plexus::Reference::Entity::Method;

=abstract A reference to documentation for a class method.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Entity';


use constant POD_COMMAND  => 'method';


sub BUILD {
	my $self = shift();

	my ($module_name, $symbol_name) = $self->_parse_method_spec();

	return unless defined $module_name and length $module_name;

	$self->symbol($symbol_name);

	my $module = $self->library()->get_document($module_name);
	unless ($module) {
		push @{$self->errors()}, (
			"=method cannot find module $module_name" .
			" at " . $self->document()->pathname() .
			" line " .  $self->node()->{start_line}
		);
		return;
	}

	my $entity = $self->document()->_get_method($symbol_name);
	unless ($entity) {
		my $symbol = $self->node()->{content};
		$symbol =~ s/\s+$//;

		push @{$self->errors()}, (
			"Cannot find implementation for '=method $symbol'" .
			" at " . $self->document()->pathname() .
			" line " .  $self->node()->{start_line}
		);
		return;
	}

	$self->push_documentation(
		Pod::Elemental::Element::Generic::Command->new(
			command => "method",
			content => "$symbol_name\n",
		),
	);
}


sub _parse_method_spec {
	my $self = shift();

	if ($self->node()->{content} =~ /^\s* (\S+) \s*$/x) {
		return($self->document()->package(), $1);
	}

	push @{$self->errors()}, (
		"Wrong syntax: =method " . $self->node()->{content} .
		" at " . $self->document()->pathname() .
		" line " . $self->node()->{start_line}
	);

	return;
}


no Moose;

1;

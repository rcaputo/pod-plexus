package Pod::Plexus::Reference::Entity::Method;

=abstract A reference to documentation for a class method.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Entity';

use constant POD_COMMAND  => 'method';
use constant POD_PRIORITY => 1000;

has '+includes_text' => (
	default => 1,
);


sub new_from_elemental_command {
	my ($class, $library, $document, $errors, $node) = @_;

	my ($module_name, $symbol_name) = $class->_parse_method_spec(
		$document, $errors, $node
	);

	return unless defined $module_name and length $module_name;

	my $module = $library->get_document($module_name);
	unless ($module) {
		push @$errors, (
			"=method cannot find module $module_name" .
			" at " . $document->pathname() . " line " . $node->{start_line}
		);
		return;
	}

	my $entity = $document->_get_method($symbol_name);
	unless ($entity) {
		push @$errors, (
			"Cannot find method $symbol_name in '=method'" .
			" at " . $document->pathname() . " line " . $node->{start_line}
		);
		return;
	}

	my $reference = $class->new(
		invoked_in    => $document->package(),
		module        => $module_name,
		symbol        => $symbol_name,
		invoke_path   => $document->pathname(),
		invoke_line   => $node->{start_line},
		documentation => [
			Pod::Elemental::Element::Generic::Command->new(
				command => "(method)",
				content => "$symbol_name\n",
			),
			Pod::Elemental::Element::Generic::Blank->new(content => "\n"),
		]
	);

	return $reference;
}


sub dereference {
	undef;
}


sub expand {
	my ($class, $document, $errors, $node) = @_;

	my ($module, $symbol) = $class->_parse_method_spec(
		$document, $errors, $node
	);

	return $document->get_reference($class, $module, $symbol);
}


sub _parse_method_spec {
	my ($class, $document, $errors, $node) = @_;

	if ($node->{content} =~ /^\s* (\S+) \s*$/x) {
		return($document->package(), $1);
	}

	push @$errors, (
		"Wrong syntax: =method $node->{content}" .
		" at " . $document->pathname() . " line $node->{start_line}"
	);

	return;
}

no Moose;

1;

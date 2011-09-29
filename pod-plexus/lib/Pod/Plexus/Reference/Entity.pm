package Pod::Plexus::Reference::Entity;

=abstract A reference to documentation for an attribute or method entity.

=cut

use Moose;
extends 'Pod::Plexus::Reference';

sub new_from_elemental_command {
	my ($class, $library, $document, $errors, $node) = @_;

	# Parse the content into a module and POD entry name to include.

	my ($module, $symbol) = $class->_parse_include_spec(
		$document, $errors, $node
	);

	return unless $module;

	my $reference = $class->new(
		invoked_in  => $document->package(),
		module      => $module,
		symbol      => $symbol,
		invoke_path => $document->pathname(),
		invoke_line => $node->{start_line},
	);

	return $reference;
}


sub _parse_include_spec {
	my ($class, $document, $errors, $node) = @_;

	if ($node->{content} =~ m!^\s* (\S*) \s+ (\S.*?) \s*$!x) {
		return($1, $2);
	}

	if ($node->{content} =~ m!^\s* (\S*) \s*$!x) {
		return($document->package(), $1);
	}

	push @$errors, (
		"Wrong inclusion syntax: =include $node->{content}" .
		" at " . $document->pathname() . " line $node->{start_line}"
	);

	return;
}


sub consume_element {
	my ($self, $element) = @_;

	return 0 if $self->is_terminated();

	if ($element->isa('Pod::Elemental::Element::Generic::Command')) {

		my $command = $element->{command};

		# "=cut" is consumed.

		if ($command eq 'cut') {
			$self->push_cut();
			$self->is_terminated(1);
			return 1;
		}

		# Other terminal top-level commands aren't consumed.
		# They do however imply "=cut".

		if ($command =~ /^head\d$/) {
			$self->push_cut();
			$self->is_terminated(1);
			return 0;
		}
	}

	# Other entities terminate this one.

	if ($element->isa('Pod::Plexus::Reference::Entity')) {
		$self->push_cut();
		$self->is_terminated(1);
		return 0;
	}

	# Otherwise, consume the documentation.

	$self->push_documentation($element);
	return 1;
}


no Moose;

1;

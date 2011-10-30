package Pod::Plexus::Docs::Code;

=abstract A reference to documentation for an attribute or method entity.

=cut

use Moose;
extends 'Pod::Plexus::Docs';

sub new_from_elemental_command {
	my ($class, $distribution, $module, $errors, $node) = @_;

	# Parse the content into a module and POD entry name to include.

	my $parser = "_parse_" . $class->POD_COMMAND() . "_spec";
	my ($module_name, $symbol) = $class->$parser();

	return unless $module_name;

	my $reference = $class->new(
		invoked_in  => $module->package(),
		module      => $module_name,
		symbol      => $symbol,
		invoke_path => $module->pathname(),
		invoke_line => $node->{start_line},
	);

	return $reference;
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

	if ($element->isa('Pod::Plexus::Docs::Code')) {
		$self->push_cut();
		$self->is_terminated(1);
		return 0;
	}

	# Otherwise, consume the documentation.

	$self->push_documentation($element);
	$self->push_body($element);
	return 1;
}


has body => (
	is      => 'rw',
	isa     => 'ArrayRef[Pod::Elemental::Paragraph|Pod::Plexus::Docs]',
	traits  => [ 'Array' ],
	lazy    => 1,
	builder => '_build_body',
	handles => {
		push_body => 'push',
	},
);


sub _build_body {
	return [ ];
}


no Moose;

1;

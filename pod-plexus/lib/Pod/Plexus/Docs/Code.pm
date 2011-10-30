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
		definition_file    => $module->pathname(),
		definition_line    => $node->{start_line},
		definition_package => $module->package(),
		module             => $module_name,
		symbol             => $symbol,
	);

	return $reference;
}


sub consume_element {
	my ($self, $element) = @_;

	return 0 if $self->is_terminated();

	my ($is_terminated, $is_consumed) = $self->_is_terminal_element(
		$self, $element
	);

	return $is_consumed if $is_terminated;

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

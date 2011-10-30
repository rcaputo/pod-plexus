package Pod::Plexus::Docs::Macro;

=abstract A reference to a macro definition.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


use constant POD_COMMAND  => 'macro';


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


sub BUILD {
	my $self = shift();

	my ($symbol) = ($self->node()->{content} =~ /^\s* (\S+) \s*$/x);
	unless (defined $symbol) {
		push @{$self->errors()}, (
			"Wrong macro syntax: =macro " . $self->node()->{content} .
			" at " . $self->module_path() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->symbol($symbol);
}


sub consume_element {
	my ($self, $element) = @_;

	return 0 if $self->is_terminated();

	my ($is_terminated, $is_consumed) = $self->_is_terminal_element(
		$self, $element
	);

	return $is_consumed if $is_terminated;

	# Otherwise, consume the documentation.

	$self->push_body($element);
	return 1;
}


no Moose;

1;

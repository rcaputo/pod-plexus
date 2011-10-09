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
			" at " . $self->document()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->symbol($symbol);
}


sub consume_element {
	my ($self, $element) = @_;

	return 0 if $self->is_terminated();

	if ($element->isa('Pod::Elemental::Element::Generic::Command')) {

		my $command = $element->{command};

		# "=cut" isn't consumed.

		if ($command eq 'cut') {
			$self->is_terminated(1);
			return 1;
		}

		# Other terminal top-level commands aren't consumed.
		# They do however imply "=cut".

		if ($command =~ /^head\d$/) {
			$self->is_terminated(1);
			return 0;
		}
	}

	# Other entities terminate this one.

	if ($element->isa('Pod::Plexus::Docs::Code')) {
		$self->is_terminated(1);
		return 0;
	}

	# Otherwise, consume the documentation.

	$self->push_body($element);
	return 1;
}


no Moose;

1;

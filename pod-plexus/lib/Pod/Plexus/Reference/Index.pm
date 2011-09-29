package Pod::Plexus::Reference::Index;

=abstract A reference to a dynamically generated module index.

=cut

use Moose;
extends 'Pod::Plexus::Reference';


has '+symbol' => (
	default => "",
);


use constant POD_COMMAND => 'index';


sub BUILD {
	my $self = shift();

	my ($header_level, $regexp) = $self->_parse_content();

	return unless $regexp;

	my @referents = sort grep /$regexp/, $self->library()->get_module_names();

	unless (@referents) {
		push @{$self->errors()}, (
			"=index $regexp ... doesn't match anything" .
			" at " . $self->document()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->push_documentation(
		map {
			my $foreign_document = $self->library()->get_document($_);

			$foreign_document->prepare_to_render($self->errors());
			return if @{$self->errors()};

			my $abstract = $self->library()->get_document($_)->abstract();
			$abstract = "No abstract defined." unless (
				defined $abstract and length $abstract
			);

			Pod::Elemental::Element::Generic::Command->new(
				command => "head" . $header_level,
				content => "\n",
			),
			Pod::Elemental::Element::Generic::Blank->new(
				content => "\n",
			),
			Pod::Elemental::Element::Generic::Text->new(
				content => "L<$_|$_> - $abstract\n",
			),
			Pod::Elemental::Element::Generic::Blank->new(
				content => "\n",
			),
		}
		@referents
	);
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
		$self->is_terminal(1);
		return 0;
	}

	# Otherwise, discard the documentation.

	return 1 if $element->isa('Pod::Elemental::Element::Generic::Blank');

	$element->{content} =~ s/^/Illegal content in =index: /;
	$self->push_documentation($element);
	return 1;
}


sub _parse_content {
	my $self = shift();

	my $regexp = $self->node()->{content};

	my $header_level = (
		($regexp =~ s/^\s*(\d+)\s*//)
		? $1
		: 2
	);

	$regexp =~ s/\s+//g;

	unless (length $regexp) {
		push @{$self->errors()}, (
			"=" . $self->node()->{command} . " command needs a regexp" .
			" at " . $self->document()->pathname() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	return( $header_level, qr/$regexp/ );
}


no Moose;

1;

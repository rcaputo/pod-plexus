package Pod::Plexus::Reference::Index;

=abstract A reference to a dynamically generated module index.

=cut

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	required => 0,
);

has header_level => (
	is       => 'ro',
	isa      => 'Num',
	required => 1,
);

use constant POD_COMMAND => 'index';

sub new_from_ppi_node {
	my ($class, $document, $errors, $node) = @_;

	my ($header_level, $regexp) = $class->_parse_content(
		$document, $errors, $node
	);
	return unless $regexp;

	return(
		$class->new(
			invoked_in   => $document->package(),
			module       => $regexp,
			header_level => $header_level,
			invoke_path  => $document->pathname(),
			invoke_line  => $node->{start_line},
		)
	);
}

sub dereference {
	my ($self, $library, $document, $errors) = @_;

	my $referent_regexp = $self->module();

	my @referents = sort grep /$referent_regexp/, $library->get_module_names();

	unless (@referents) {
		push @$errors, (
			"=index $referent_regexp ... doesn't match anything" .
			" at " . $self->invoke_path() . " line " . $self->invoke_line
		);
		return;
	}

	$self->documentation(
		[
			map {
				my $foreign_document = $library->get_document($_);

				$foreign_document->collect_data($errors);

				my $abstract = $library->get_document($_)->abstract();
				$abstract = "No abstract defined." unless (
					defined $abstract and length $abstract
				);

				Pod::Elemental::Element::Generic::Command->new(
					command => "head" . $self->header_level(),
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
		]
	);
}

sub expand {
	my ($class, $document, $errors, $node) = @_;

	my ($header_level, $regexp) = $class->_parse_content(
		$document, $errors, $node
	);
	return unless $regexp;

	my $reference = $document->get_reference(
		'Pod::Plexus::Reference::Index', $regexp, ""
	);

	unless ($reference) {
		push @$errors, (
			"Can't find =index $$regexp" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
		return;
	}

	return $reference;

}

sub _parse_content {
	my ($class, $document, $errors, $node) = @_;

	my $regexp = $node->{content};

	my $header_level = (
		($regexp =~ s/^\s*(\d+)\s*//)
		? $1
		: 2
	);

	$regexp =~ s/\s+//g;

	unless (length $regexp) {
		push @$errors, (
			"=$node->{command} command needs a regexp" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
		return;
	}

	return( $header_level, qr/$regexp/ );
}

no Moose;

1;

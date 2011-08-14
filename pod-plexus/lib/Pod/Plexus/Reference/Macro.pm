package Pod::Plexus::Reference::Macro;

=abstract A reference to a macro definition.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Include';

use constant POD_COMMAND => 'macro';


has '+discards_command' => (
	default => 1,
);


has '+includes_text' => (
	default => 1,
);


sub new_from_ppi_node {
	my ($class, $document, $errors, $node) = @_;

	my ($symbol) = ($node->{content} =~ /^\s* (\S+) \s*$/x);
	unless (defined $symbol) {
		push @$errors, (
			"Wrong macro syntax: =macro $node->{content}" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
		return;
	}

	my $reference = $class->new(
		invoked_in  => $document->package(),
		module      => $document->package(),
		symbol      => $symbol,
		invoke_path => $document->pathname(),
		invoke_line => $node->{start_line},
	);

	return $reference;
}

sub dereference {
	my $self = shift;
	warn $_->as_pod_string() foreach @{$self->documentation()};
	undef;
}

sub expand {
	die;
}

no Moose;

1;

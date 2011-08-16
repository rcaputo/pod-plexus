package Pod::Plexus::Reference::Demacro;

=abstract A reference to a macro expansion.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Include';

use constant POD_COMMAND  => 'demacro';
use constant POD_PRIORITY => 5000;


sub new_from_elemental_command {
	my ($class, $library, $document, $errors, $node) = @_;

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
	undef;
}

sub expand {
	my ($class, $document, $errors, $node) = @_;

	my $module = $document->package();
	my ($symbol) = ($node->{content} =~ /^\s* (\S+) \s*$/x);
	my $reference = $document->get_reference(
		'Pod::Plexus::Reference::Macro', $module, $symbol
	);

warn $document->package(), " = $symbol";
	unless ($reference) {
		push @$errors, (
			"Can't find reference for =demacro $symbol" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
	}

	return $reference;
}

no Moose;

1;


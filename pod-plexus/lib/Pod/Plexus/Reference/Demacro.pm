package Pod::Plexus::Reference::Demacro;

=abstract A reference to a macro expansion.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Include';


use constant POD_COMMAND  => 'demacro';


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


sub resolve {
	my $self = shift();

	my $reference = $self->document()->get_reference(
		'Pod::Plexus::Reference::Macro',
		$self->document()->package(),
		$self->symbol()
	);

	unless ($reference) {
		push @{$self->errors()}, (
			"Can't find reference for =demacro " . $self->symbol() .
			" at " . $self->document()->pathname() .
			" line " . $self->node()->{start_line}
		);
	}
}


no Moose;

1;


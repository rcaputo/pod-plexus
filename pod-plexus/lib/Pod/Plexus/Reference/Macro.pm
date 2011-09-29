package Pod::Plexus::Reference::Macro;

=abstract A reference to a macro definition.

=cut

use Moose;
extends 'Pod::Plexus::Reference::Include';


use constant POD_COMMAND  => 'macro';


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


no Moose;

1;

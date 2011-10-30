package Pod::Plexus::Docs::Demacro;

=abstract A reference to a macro expansion.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


use constant POD_COMMAND  => 'demacro';


sub BUILD {
	my $self = shift();

	my ($symbol_name) = ($self->node()->{content} =~ /^\s* (\S+) \s*$/x);
	unless (defined $symbol_name) {
		push @{$self->errors()}, (
			"Wrong macro syntax: =macro " . $self->node()->{content} .
			" at " . $self->module_path() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->symbol($symbol_name);

	# The macro must already exist.

	my $reference = $self->module()->get_documentation(
		'Pod::Plexus::Docs::Macro',
		$self->module_package(),
		$self->symbol()
	);
	unless ($reference) {
		push @{$self->errors()}, (
			"Cannot find macro $symbol_name in '=demacro'" .
			" at " . $self->module_path() .
			" line " . $self->node()->{start_line}
		);
		return;
	}

	$self->push_documentation(@{ $reference->body() // [] });
}


no Moose;

1;


package Pod::Plexus::Docs::Cross;

=abstract Remember and render cross-references.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


use constant POD_COMMAND  => 'xref';


has '+symbol' => (
	default => sub {
		my $self = shift();
		return $self->module_package();
	},
);


has '+module' => (
	default => sub {
		my $self = shift();
		return($self->node()->{content} =~ /^\s* (\S.*?) \s*$/x);
	},
);


sub dereference {
	my ($self, $distribution, $module, $errors) = @_;

	my $referent_name = $self->module_package();
	my $referent = $distribution->get_module($referent_name);

	$self->documentation(
		[
			generic_command("item", "*\n"),
			blank_line(),
			text_paragraph(
				"L<$referent_name|$referent_name> - " . $referent->abstract()
			),
			blank_line(),
		],
	);
}


no Moose;

1;

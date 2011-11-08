package Pod::Plexus::Docs::attribute;

=abstract A reference to documentation for a class attribute.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command blank_line);


sub is_top_selector { 1 }


has '+doc_prefix' => (
	default => sub {
		my $self = shift();
		return [
			generic_command("attribute", $self->name() . "\n"),
			blank_line(),
		];
	},
);


no Moose;

1;

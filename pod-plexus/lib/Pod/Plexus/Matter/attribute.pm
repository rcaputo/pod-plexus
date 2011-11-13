package Pod::Plexus::Matter::attribute;

=abstract A reference to documentation for a class attribute.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command blank_line);


sub is_top_level { 1 }


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

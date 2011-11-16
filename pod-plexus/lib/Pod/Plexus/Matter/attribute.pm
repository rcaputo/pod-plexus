package Pod::Plexus::Matter::attribute;

=abstract Document a class attribute in an inheritable way.

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

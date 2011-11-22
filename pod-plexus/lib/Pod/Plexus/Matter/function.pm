package Pod::Plexus::Matter::function;

# TODO - Edit pass 0 done.

=abstract Document a package function.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Code';

use Pod::Plexus::Util::PodElemental qw(generic_command blank_line);


sub is_top_level { 1 }


has '+doc_prefix' => (
	default => sub {
		my $self = shift();
		return [
			generic_command("function", $self->name() . "\n"),
			blank_line(),
		];
	},
);


no Moose;

1;

package Pod::Plexus::Matter::Reference;

=abstract An abstract section that references something else.

=cut

use Moose;
extends 'Pod::Plexus::Matter';


has referent => (
	is       => 'rw',
	isa      => 'Pod::Plexus::Matter',
	weak_ref => 1,
);


sub BUILD {
	my $self = shift();
	# TODO - Anything?  Bueller?
}


no Moose;

1;

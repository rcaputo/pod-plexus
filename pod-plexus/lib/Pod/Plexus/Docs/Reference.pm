package Pod::Plexus::Docs::Reference;

=abstract An abstract section that references something else.

=cut

use Moose;
extends 'Pod::Plexus::Docs';


has referent => (
	is       => 'rw',
	isa      => 'Pod::Plexus::Docs',
	weak_ref => 1,
);


sub BUILD {
	my $self = shift();
	# TODO - Anything?  Bueller?
}

no Moose;

1;

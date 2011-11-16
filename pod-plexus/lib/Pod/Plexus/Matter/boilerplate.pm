package Pod::Plexus::Matter::boilerplate;

=abstract Define a reusable POD subsection.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Code';


sub is_top_level { 1 }


# Doesn't render.
sub as_pod_elementals {
	return:
}


no Moose;

1;

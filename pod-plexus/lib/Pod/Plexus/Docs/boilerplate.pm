package Pod::Plexus::Docs::boilerplate;

=abstract A reference to a macro definition.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Code';


sub is_top_level { 1 }


# Doesn't render.
sub as_pod_elementals {
	return:
}


no Moose;

1;

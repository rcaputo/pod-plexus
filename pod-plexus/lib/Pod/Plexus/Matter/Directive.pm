package Pod::Plexus::Matter::Directive;

# TODO - Edit pass 0 done.

=abstract A base class for Pod::Plexus parser and renderer directives.

=cut

use Moose;
extends 'Pod::Plexus::Matter';


sub is_top_level { 1 }


# Doesn't render.
sub as_pod_elementals {
	return;
}


no Moose;

1;

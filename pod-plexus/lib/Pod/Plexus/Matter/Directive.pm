package Pod::Plexus::Matter::Directive;
# TODO - Edit pass 1 done.

=abstract A base class for Pod::Plexus parser and renderer directives.

=cut

use Moose;
extends 'Pod::Plexus::Matter';


sub is_top_level { 1 }


=after as_pod_elementals

Pod::Plexus directives don't render as POD, so [% s.name %]() always
returns an empty list.

=cut

sub as_pod_elementals {
	return;
}


no Moose;

1;

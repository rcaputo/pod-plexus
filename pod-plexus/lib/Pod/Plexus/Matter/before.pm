package Pod::Plexus::Matter::before;

# TODO - Edit pass 0 done.

=abstract Inherit documentation, and prepend new content before it.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';
with 'Pod::Plexus::Matter::Role::PrependToBody';

use Pod::Plexus::Util::PodElemental qw(blank_line);

no Moose;

1;

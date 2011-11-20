package Pod::Plexus::Matter::before;

=abstract Inherit documentation, and prepend new content before it.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';
with 'Pod::Plexus::Matter::Role::PrependToBody';

use Pod::Plexus::Util::PodElemental qw(blank_line);

no Moose;

1;

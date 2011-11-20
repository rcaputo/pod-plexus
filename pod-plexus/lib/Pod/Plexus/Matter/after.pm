package Pod::Plexus::Matter::after;

# TODO - Edit pass 0 done.

=abstract Inherit documentation, and append new content to the section.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';
with 'Pod::Plexus::Matter::Role::AppendToBody';

no Moose;

1;

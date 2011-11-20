package Pod::Plexus::Matter::before;

=abstract Inherit documentation, and prepend new content before it.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';

use Pod::Plexus::Util::PodElemental qw(blank_line);


sub section_body_handler { 'prepend_my_body' }


no Moose;

1;

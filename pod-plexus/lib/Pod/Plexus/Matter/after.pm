package Pod::Plexus::Matter::after;

=abstract Inherit documentation, and append new content to the section.

=cut

use Moose;
extends 'Pod::Plexus::Matter::inherits';

use Pod::Plexus::Util::PodElemental qw(blank_line);


sub section_body_handler { 'append_my_body' }


no Moose;

1;

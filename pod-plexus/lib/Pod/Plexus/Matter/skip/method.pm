package Pod::Plexus::Matter::skip::method;

# TODO - Edit pass 0 done.

=abstract Represent the need to skip a method in a module.

=cut

use Moose;
extends 'Pod::Plexus::Matter::skip';


# It actually does nothing except represent a particular type of skip.
# Its presence or absence in the module's matter dictates whether to
# skip.


no Moose;

1;

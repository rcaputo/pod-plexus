package Pod::Plexus::Matter::skip::method;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Matter::skip';


=abstract Represent the need to skip a method in a module.

=cut


=head1 SYNOPSIS

	=skip method BUILD

	=skip method DESTRUCT

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] implements the "=skip method" directive, which tells
Pod::Plexus to skip compling and validating the documentation for a
method in the current package.

=include boilerplate skip_purpose

=cut


# It actually does nothing except represent a particular type of skip.
# Its presence or absence in the module's matter dictates whether to
# skip.


no Moose;

1;

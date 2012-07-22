package Pod::Plexus::Matter::before;

# TODO - Edit pass 0 done.

=abstract Inherit documentation, and prepend new content before it.

=cut


=head1 SYNOPSIS

	=before Package [attribute|method] symbol_name

	The documentation for the symbol_name attribute or method will be
	inherited.  New content in the "=before" section will be added
	before the inherited documentation.

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] implenents the "=before" Pod::Plexus directive.  This
allows POD to incorporate POD from another package's attribute or
method documentation and append new content.

=include Pod::Plexus::Matter::inherits boilerplate expansions

=cut


use Moose;
extends 'Pod::Plexus::Matter::inherits';
with 'Pod::Plexus::Matter::Role::PrependToBody';

use Pod::Plexus::Util::PodElemental qw(blank_line);

no Moose;

1;

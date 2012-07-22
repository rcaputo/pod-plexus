package Pod::Plexus::Matter::after;

# TODO - Edit pass 0 done.

=abstract Inherit documentation, and append new content to the section.

=cut


=head1 SYNOPSIS

	=after Package [attribute|method] symbol_name

	The documentation for the symbol_name attribute or method will be
	inherited.  New content in the "=after" section will be added after
	the inherited documentation.

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] implenents the "=after" Pod::Plexus directive.  This
allows POD to incorporate POD from another package's attribute or
method documentation and append new content.

=include Pod::Plexus::Matter::inherits boilerplate expansions

=cut


use Moose;
extends 'Pod::Plexus::Matter::inherits';
with 'Pod::Plexus::Matter::Role::AppendToBody';

no Moose;

1;

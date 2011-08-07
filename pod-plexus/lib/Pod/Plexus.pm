package Pod::Plexus;

use Pod::Plexus::Library;
use Pod::Plexus::Document;

1;

__END__

=abstract An intricate network or weblike formation of POD.

=head1 DESCRIPTION

Modules don't exist in a vacuum.
They are pointless unless used.
Their users provide the contexts in which they exist.

Good module documentation requires context too.
It's insufficient to document a module in isolation.
At the very least, examples imply practical contexts.

In a sense documentation is technical debt.
Documentation decribes fluid implementation.
Both must change in unison.

Pod::Plexus aims to help.
Code becomes part of the documentation.
If your code is ugly, go home.

L<Pod::Plexus::Library> describes a library of documents.
L<Pod::Plexus::Document> encapsulates a single file's documentation.
The L<podplexus> command line utility drives it all.

L<Dist::Zilla::Plugin::PodPlexus> provides additional integration.
As may L<Pod::Weaver::Plugin::PodPlexus> in the future.
If it can get around Pod::Weaver's limitations.

PPI is used to inspect and index code.
Pod::Elemental dissects documentation for analysis and retrojiggering.
Together, they fight bad documentation.

=head2 New Directives

Pod::Plexus provide some new POD directives.
This is an early draft.
Things may change.

=head3 =abstract TEXT

Define the module's one-line description.  Dist::Zilla supports the
"abstract" comment, but it seems incongruous for some comments to be
treated as POD directives.

The module's NAME is taken from the first package() statement in the
code.  Corollary: It's best to have only one package per file.

	=abstract An intricate network of weblike formation of POD.

The abstract and name of each module may be used by other directives.
For example, see L<=xref MODULE_NAME>.

=head3 =copyright YEARS HOLDER_NAME

Define the copyright year and the name of the entity who holds it.  It
renders in place as a basic copyright section.

This directive is obsolete unless someone can justify why
Pod::Weaver's copious and configurable copyright plugins aren't
suitable.

	=copyright 2010-2011 Rocco Caputo

=head3 =example METHOD_NAME

Include an example paragraph in the current documentation.  The
content is the method named by METHOD_NAME in the current module.
Method names must not include colons.  The presence of a colon
indicates a module name.  This must change before the module is
considered stable.

Include the contents of new() from the current module:

	=example new

=head3 =example MODULE_NAME

Include an example paragraph in the current documentation, using the
entire implementation of the module named MODULE_NAME.  This is only
practical for very small modules.  Object orientation gives plenty of
opportunity to do this, however.  MODULE_NAME must include a colon,
which is a fatal flaw in the plan.  Top-level modules don't have
colons in their names.

Include the code contents of Reflex::Eg::Inheritance::Moose:

	=example Reflex::Eg::Inheritance::Moose

=head3 =example MODULE_NAME METHOD_NAME

Include an example paragraph in the current documentation.  The
content is that of METHOD_NAME in some other MODULE_NAME.  One may
also use it to explicitly include a method in the current module, but
that's more work.

Include the implementation of render() from Pod::Plexus::Document:

	=example Pod::Plexus::Document render

=head3 =include MODULE_NAME SECTION_NAME

Include documentation from this or another module, named by
MODULE_NAME.  The inclusion will be limited to the section named by
SECTION_NAME.

This directive's intent is to reduce the effort of documenting
multiple similar things.  For example, each module implementing a
common API may include documentation from a base class.

A less satisfying alternatives include omitting the documentation
entirely, in which case the user may not know about some existing
features.  Another alternative is to direct the user up the
inheritance chain, which becomes tedious very fast.

	=head1 DESCRIPTION

	This module is nearly identical to Reflex::Eg::Inheritance::Moose.
	It only differs in the mechanism of subclassing Reflex::Timeout.

	=include Reflex::Eg::Inheritance::Moose DESCRIPTION

=head3 =index REGEXP

Index a group of modules whose names match a given REGEXP.  It
generates an L<=xref MODULE_NAME> entry for each matching module.  See
the "=xref" directive for details.

	package Reflex::Eg;

	1;

	=pod

	=abstract Index of Reflex Examples

	=head1 EXAMPLES

	=over 4

	=index ^Reflex::Eg::

	=back

	=cut

=head3 =xref MODULE_NAME

Include a list item referring to another module by its MODULE_NAME.

	=head1 SEE ALSO

	=over 4

	=xref Pod::Plexus::Document

	=back

As of this writing, the rendered form would be:

	=head1 SEE ALSO

	=over 4

	=item *

	L<Pod::Plexus::Document|Pod::Plexus::Document> -
	Represent and render a single Pod::Plexus document.

	=back

The actual form may change over time.  This annoys me, so I'm looking
for a way to keep the documentation up to date automatically.

=cut

=xref Pod::Plexus::Document

=cut

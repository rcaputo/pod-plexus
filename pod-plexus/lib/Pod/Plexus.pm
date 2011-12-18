package Pod::Plexus;

# TODO - Edit pass 1 done.

=abstract Reduces POD maintenance by adding documenation by reference.

=cut

use Pod::Plexus::Distribution;
use Pod::Plexus::Module;

1;

=head1 DESCRIPTION

=over 4

=item

B<plex-us> (plek'səs), n., B<1.> a network of nerve fibers, blood
vessels, lymphatics, etc.: I<The solar plexus is a collection of>
I<nerves behind the stomach.>  B<2.> any intertwined or interwoven
mass; web; network.  [< New Latin I<plexus> < Latin I<plexus>, a braid
< I<plectere> to twine, braid]

=back

Documentation is a drag.  It adds significant friction to development,
since it must be edited to reflect changes in the code.  As tedious as
code is to test, documentation is many times worse to validate.  A
human with a deep understanding of the code must read everything and
evaluate whether it holds true.

Relatively few people relish this task, which is why so much open
source documentation sucks.  People usually fine something else to do,
and the documentation suffers.

Pod::Plexus reduces documentation's drag.  It adds "documentation by
reference", reducing the amount of work needed to document things
thoroughly.  Documentation by reference reduces the number of places
where edits must be made, making maintenance a bit easier.

For example, Pod::Plexus adds inheritance to POD.  Documentation can
be written once in base classes and roles.  Subclasses and consumers
can include it in their own documentation.

Pod::Plexus allows documentation to use real code for examples.  Fixes
applied to implementation automatically update the illustrations.

POD sections are treated as templates.  Aspects of the section and its
context can be plugged into the documentation by reference.  For
example, a section's prose can reference the section heading name
symbolically.  The section stays up to date when its heading is
renamed.

Tables of contents can be generated in a single line.  Base classes
can automatically include links to all the subclasses that accompany
it in the distribution.

Documentation is a bit more like code, so it should be a little more
enjoyable to write. :)

=head1 NEW POD COMMANDS

Pod::Plexus commands are implemented in their own classes.  This
modular approach is intended to simplify writing and releasing new
commands.

Please see the following modules for documentation of specific
commands.

=toc ^Pod::Plexus::Matter::[a-z][^:]*$

=head1 SEE ALSO

L<Dist::Zilla::Plugin::PodPlexus> integrates Pod::Plexus with
Dist::Zilla.

L<Pod::Weaver::Plugin::PodPlexus> is an ongoing attempt to integrate
Pod::Plexus with Pod::Weaver, if it's possible.  Help wanted!

The L<podplexus> command line utility comes with this distribution.
It's used to speed up development and testing, but it's not ready for
general usage at the time of this writing.  Help wanted to make it a
useful stand-alone tool for people who would rather not use
Dist::Zilla.

Pod::Plexus leans heavily on L<PPI> and L<Moose> for code analysis.
It uses L<Pod::Elemental> to wrangle documentation.  Patches to reduce
the number and/or complexity of dependencies are very welcome.

In its default state, Pod::Plexus requires L<Pod::Weaver> or something
like it to gather and render =method and =attribute sections.  POD can
be rendered instead by subclassing L<Pod::Plexus::Matter::attribute>
and L<Pod::Plexus::Matter::method>.

=cut

=boilerplate new

[% s.name %]() constructs one [% m.package %] object.
Because [% s.name %]() uses Moose, the caller can supply constructor
parameters named after this class' public attributes.
See L</PUBLIC ATTRIBUTES> for a list of configurable construction
options.

=cut

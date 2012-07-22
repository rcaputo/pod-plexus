package Pod::Plexus::Matter::Pod;
# TODO - Edit pass 1 done.


=abstract A base class for Pod::Plexus wrappers around POD.

=cut


=head1 SYNOPSIS

=xref module Pod::Plexus::Matter::head1

=cut


=head1 DESCRIPTION

[% m.package %] is a base class for Pod::Plexus objects that parse and
manage Perl's plain old documentation (POD).  The subclasses do most
of the work, if not all of it.

=cut


use Moose;
extends 'Pod::Plexus::Matter';

1;

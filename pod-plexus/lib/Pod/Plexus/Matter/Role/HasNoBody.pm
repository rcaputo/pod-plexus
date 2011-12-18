package Pod::Plexus::Matter::Role::HasNoBody;
# TODO - Edit pass 1 done.

=abstract Ignore any section text following a Pod::Plexus command.

=cut

use Moose::Role;

excludes qw(handle_body);


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The "=[% command %]" command is not a POD container.  It has no
associated POD content.

=cut


sub handle_body {
	# Does nothing.
}


1;

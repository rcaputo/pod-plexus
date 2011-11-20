package Pod::Plexus::Matter::Role::HasNoBody;

# TODO - Edit pass 0 done.

use Moose::Role;

requires qw(push_body extract_my_body);
excludes qw(handle_body);


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The [% command %] command is not a POD container.  It has no
associated POD content.

=cut


sub handle_body {
	# Does nothing.
}


1;

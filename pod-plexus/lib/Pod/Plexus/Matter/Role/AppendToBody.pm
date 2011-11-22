package Pod::Plexus::Matter::Role::AppendToBody;

# TODO - Edit pass 0 done.

=abstract Append any text following a Pod::Plexus command to the resulting object's content.

=cut

use Moose::Role;

requires qw(push_body extract_my_body);
excludes qw(handle_body);

use Pod::Plexus::Util::PodElemental qw(blank_line);


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The POD associated with the [% command %] command will be extracted
and appended to any documentation previously provided elsewhere.

=cut


sub handle_body {
	my $self = shift();
	$self->push_body( blank_line(), $self->extract_my_body() );
}


1;

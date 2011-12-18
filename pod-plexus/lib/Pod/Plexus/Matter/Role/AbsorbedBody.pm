package Pod::Plexus::Matter::Role::AbsorbedBody;
# TODO - Edit pass 1 done.

use Moose::Role;

requires qw(push_body extract_my_body);
excludes qw(handle_body);


=abstract Absorb any section text after a Pod::Plexus command into the resulting object.

=cut


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The POD associated with the "=[% command %]" command will be extracted
and used as the body of any generated POD section.

=cut


sub handle_body {
	my $self = shift();
	$self->push_body( $self->extract_my_body() );
}


1;

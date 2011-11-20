package Pod::Plexus::Matter::Role::AbsorbedBody;

use Moose::Role;

requires qw(push_body extract_my_body);
excludes qw(handle_body);


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The POD associated with the [% command %] command will be extracted
and used as the body of any generated POD section.

=cut


sub handle_body {
	my $self = shift();
	$self->push_body( $self->extract_my_body() );
}


1;

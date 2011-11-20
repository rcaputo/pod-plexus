package Pod::Plexus::Matter::Role::PrependToBody;

# TODO - Edit pass 0 done.

use Moose::Role;

requires qw(unshift_body extract_my_body);
excludes qw(handle_body);

use Pod::Plexus::Util::PodElemental qw(blank_line);


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The POD associated with the [% command %] command will be extracted
and prepended to any documentation previously provided elsewhere.

=cut


sub handle_body {
	my $self = shift();
	$self->unshift_body( $self->extract_my_body(), blank_line() );
}


1;

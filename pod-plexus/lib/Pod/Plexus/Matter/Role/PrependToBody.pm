package Pod::Plexus::Matter::Role::PrependToBody;
# TODO - Edit pass 1 done.

use Moose::Role;

requires qw(unshift_body extract_my_body);
excludes qw(handle_body);

use Pod::Plexus::Util::PodElemental qw(blank_line);


=abstract Prepend any text following a Pod::Plexus command before the resulting object's content.

=cut


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The POD associated with the "=[% command %]" command will be extracted
and prepended to any documentation previously provided elsewhere.

=cut


after doc_body => sub {
	my $self = shift();
	$self->unshift_body( $self->extract_my_body(), blank_line() );
};


sub handle_body {
	# Does nothing.
	# Satisfies "excludes".
	# Gives Pod::Plexus::Matter::BUILD something to call.
}

1;

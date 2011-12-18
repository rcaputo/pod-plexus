package Pod::Plexus::Matter::Role::DiscardBody;
# TODO - Edit pass 1 done.

use Moose::Role;

requires qw(extract_my_body docs docs_index module_pathname);
excludes qw(handle_body);


=abstract Throw away any text following a Pod::Plexus command.

=cut


=boilerplate section_body_handler

[% SET command = c.match('::([a-z]+)').0 %]
The "=[% command %]" section must not contain POD content.  An error
will be thrown if any content is present.

=cut


sub handle_body {
	my $self = shift();

	my @section = $self->extract_my_body();
	return unless @section;

	my $element = $self->docs()->[ $self->docs_index() ];
	my $command = $element->command();

	die [
		"=$command section must be empty" .
		" at " . $self->module_pathname() .
		" line " . $element->start_line()
	];
}


1;

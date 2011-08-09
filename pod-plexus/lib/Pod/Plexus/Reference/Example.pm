package Pod::Plexus::Reference::Example;

use Moose;
extends 'Pod::Plexus::Reference';

has '+symbol' => (
	isa      => 'Maybe[Str]',
	required => 0,
);

=method beautify_code

[% ss.name %] beautifies the code passed to it in its only parameter.
Code is assumed to be a multiline string.  A beautified version is
returned.

=cut

sub beautify_code {
	my ($self, $code) = @_;

	# TODO - PerlTidy the code?
	# TODO - The following whitespace options are personal
	# preference.  Someone should patch them to be options.

	# Convert tab indents to fixed spaces for better typography.
	$code =~ s/\t/  /g;

	# Indent two spaces.  Remove leading and trailing blank lines.
	$code =~ s/\A(^\s*$)+//m;
	$code =~ s/(^\s*$)+\Z//m;
	$code =~ s/^/  /mg;

	return $code;
}

=method set_example

[% ss.name %] takes a POD link and a beautified code, both as strings.
It wraps the strings in appropriate Pod::Elemental objects, and
replaces the documentation() with them.

=cut

sub set_example {
	my ($self, $link, $code) = @_;
	$self->documentation(
		[
			Pod::Elemental::Element::Generic::Text->new(
				content => $link . $code,
			),
			Pod::Elemental::Element::Generic::Blank->new(
				content => "\n",
			),
		]
	);
}

no Moose;

1;

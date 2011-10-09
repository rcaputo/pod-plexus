package Pod::Plexus::Docs::Example;

=abstract A generic reference to a code example.

=cut

use Moose;
extends 'Pod::Plexus::Docs';

use Pod::Plexus::Docs::Example::Method;
use Pod::Plexus::Docs::Example::Module;

use constant POD_COMMAND => 'example';


has '+symbol' => (
	default => "",
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


sub create {
	my ($class, %args) = @_;

	# Parse the content into a module and/or sub name to include.

	my ($module, $sub) = $class->_parse_example_spec(
		$args{document}, $args{errors}, $args{node}
	);
	return unless $module;

	my $self = (
		(defined $sub)
		? (
			Pod::Plexus::Docs::Example::Method->new(
				%args,
				module => $module,
				symbol => $sub,
			)
		)
		: (
			Pod::Plexus::Docs::Example::Module->new(
				%args,
				module => $module,
			)
		)
	);

	$self->resolve();

	return $self;
}


#sub expand {
#	my ($class, $library, $document, $errors, $node) = @_;
#
#	my ($module, $sub) = $class->_parse_example_spec(
#		$document, $errors, $node
#	);
#
#	my $reference = $document->get_reference($class, $module, $sub);
#	unless ($reference) {
#		push @$errors, (
#			"Can't find =example $module $sub" .
#			" at " . $document->pathname() . " line $node->{start_line}"
#		);
#		return;
#	}
#
#	return $reference;
#}


=method _parse_example_spec

[% ss.name %] parses the specification for examples.  It's used by the
"=example" directive to identify which code is being used as an
example.

This spec parser is different than all the rest.  It's called before
[% mod.name %] is created.  The particular [% mod.name %] subclass to
create depends on _parse_example_spec()'s result.

=cut

sub _parse_example_spec {
	my ($class, $document, $errors, $node) = @_;

	my (@args) = split(/[\s\/]+/, $node->{content});

	if (@args > 2) {
		push @$errors, (
			"Too many parameters for =example $node->{content}" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
		return;
	}

	if (@args < 1) {
		push @$errors, (
			"Not enough parameters for =example $node->{content}" .
			" at " . $document->pathname() . " line $node->{start_line}"
		);
		return;
	}

	# TODO - TYPE_FILE if the spec contains a "." or "/" to indicate a
	# path name.

	# "Module::method()" or "Module method()".

	if ($node->{content} =~ /^\s*(\S+)(?:\s+|::)(\w+)\(\)\s*$/) {
		return($1, $2);
	}

	# Just "method()".

	if ($node->{content} =~ /^(\w+)\(\)$/) {
		return($document->package(), $1);
	}

	# Assuming just "Module".

	my ($package) = ($node->{content} =~ /\s*(\S.*?)\s*/);
	return($package, undef);
}


no Moose;

1;

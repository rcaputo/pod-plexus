package Pod::Plexus::Docs::example;

=abstract A generic reference to a code example.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Reference';

use Pod::Plexus::Docs::Example::Method;
use Pod::Plexus::Docs::Example::Module;

use Pod::Plexus::Util::PodElemental qw(text_paragraph);


has '+referent' => (
	isa => 'Pod::Plexus::Code',
);


sub is_top_level { 0 }


sub BUILD {
	my $self = shift();

	my $element = $self->docs()->[ $self->docs_index() ];
	my $content = $element->content();
	chomp $content;

	my ($module, $type, $symbol);

	if ($content =~ m/^\s* (module) \s+ (\S+) \s*$/x) {
		($module, $type, $symbol) = ($2, $1, undef);
	}
	elsif ($content =~ m/^\s* (\S+) \s+ (attribute|method) \s+ (\S+) \s*$/x) {
		($module, $type, $symbol) = ($1, $2, $3);
	}
	elsif ($content =~ m/^\s* (attribute|method) \s+ (\S+) \s* $/x) {
		($module, $type, $symbol) = (
			$self->module_package(), $1, $2
		);
	}
	else {
		$self->push_error(
			"Wrong syntax: (=example $content) " .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		);
		return;
	}

	my $referent_module = $self->module_distribution()->get_module($module);
	unless ($referent_module) {
		$self->push_error(
			"Unknown referent module: (=example $content) " .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		);
		return;
	}

	my @errors = $referent_module->cache_structure();
	if (@errors) {
		$self->push_error(@errors);
		return;
	}

	my ($code, $link);
	if ($type eq 'attribute') {
		$code = $referent_module->get_attribute_code($symbol);
	}
	elsif ($type eq 'method') {
		$code = $referent_module->get_sub_code($symbol);
	}
	elsif ($type eq 'module') {
		$code = $referent_module->get_module_code();
	}
	else {
		die "example type cannot be '$type'";
	}

	unless (defined $code and length $code) {
		$self->push_error(
			"Can't find code referred to by: (=include $content) " .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		);
		return;
	}

	$code = $self->beautify_code($code);
	$self->doc_body([ text_paragraph($code) ]);
}


=method beautify_code

[% ss.name %] beautifies the code passed to it in its only parameter.
Code is expected to be a single string containing multiple lines
separated by newlines.  A string of "beautified" multiple-line code is
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
	$code =~ s/(^\s*$)+\Z/\n/m;
	$code =~ s/^/  /mg;

	# Code must end in a newline.
	$code =~ s/\n*$/\n/;

	return $code;
}


no Moose;

1;

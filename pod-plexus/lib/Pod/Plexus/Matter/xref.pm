package Pod::Plexus::Matter::xref;

=abstract Generate a cross-reference link.

=cut

use Moose;
extends 'Pod::Plexus::Matter';

use Pod::Plexus::Util::PodElemental qw(
	generic_command
	text_paragraph
	blank_line
);


sub BUILD {
	my $self = shift();

	# TODO - The code to parse a module|attribute|method spec is common
	# with at least Pod::Plexus::Matter::example.  Consider hoisting
	# into a parent class.

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
			"Wrong syntax: (=xref $content) " .
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

	# However this differs from Pod::Plexus::Matter::example in that it
	# refers to a documentation entity.

	$self->push_prefix(
		generic_command("item", "*\n"),
		blank_line(),
	);

	if ($type eq 'attribute') {
		if ($module eq $self->module_package()) {
			$self->push_body(
				text_paragraph(
					"Attribute L<$symbol|/$symbol> in this class.\n"
				),
			);
			return;
		}

		$self->push_body(
			text_paragraph(
				"L<$module|$module> attribute L<$symbol()|$module/$symbol>.\n"
			)
		);
		return;
	}

	if ($type eq 'method') {
		if ($module eq $self->module_package()) {
			$self->push_body(
				text_paragraph(
					"Method L<$symbol|/$symbol> in this class.\n"
				)
			);
			return;
		}

		$self->push_body(
			text_paragraph(
				"L<$module|$module> method L<$symbol()|$module/$symbol>.\n"
			)
		);
		return;
	}

	if ($type eq 'module') {
		$self->push_body(
			text_paragraph(
				"L<$module|$module> - " . $referent_module->abstract() . "\n"
			)
		);
		return;
	}

	die "xref type cannot be '$type'";
}


no Moose;

1;

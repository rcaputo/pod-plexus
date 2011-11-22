package Pod::Plexus::Matter::xref;

# TODO - Edit pass 1 done.

=abstract Generate a cross-reference link to another part of a distribution.

=cut

=head1 SYNOPSIS

To reference a module:

	=xref module Pod::Plexus

	... becomes ...

	=item *

	L<Pod::Plexus|Pod::Plexus> - ${Pod::Plexus abstract}

To reference an attribute:

	=xref Pod::PLexus::Cli attribute verbose

	... becomes ...

	=item *

Local attributes may also be linked:

	=xref attribute verbose

	L<Pod::Plexus::Cli|Pod::Plexus::Cli>
	attribute "L<verbose|Pod::Plexus::Cli/verbose>".

To reference a method:

	=xref Pod::Plexus::Matter::Reference method get_referent_module

	... becomes ...

	=item *

	L<Pod::Plexus::Matter::Reference|Pod::Plexus::Matter::Reference>
	method
	L<get_referent_module()|Pod::Plexus::Matter::Reference/get_referent_module>

Local methods may also be linked.

	=xref method get_referent_module

=cut

=head1 DESCRIPTION

[% m.package %] turns a concise description of another module,
attribute or method into a complete and standardized POD link.

=include boilerplate please_report_questions

=cut


use Moose;
extends 'Pod::Plexus::Matter::Reference';

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

	my ($module_name, $type, $symbol);

	if ($content =~ m/^\s* (module) \s+ (\S+) \s*$/x) {
		($module_name, $type, $symbol) = ($2, $1, undef);
	}
	elsif ($content =~ m/^\s* (\S+) \s+ (attribute|method) \s+ (\S+) \s*$/x) {
		($module_name, $type, $symbol) = ($1, $2, $3);
	}
	elsif ($content =~ m/^\s* (attribute|method) \s+ (\S+) \s* $/x) {
		($module_name, $type, $symbol) = (
			$self->module_package(), $1, $2
		);
	}
	else {
		die [
			"Wrong syntax" .
			" in '=" . $element->command() . " $content'" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	}

	my $referent_module = $self->get_referent_module($module_name);

	my @errors = $referent_module->cache_structure();
	die \@errors if @errors;

	# However this differs from Pod::Plexus::Matter::example in that it
	# refers to a documentation entity.

	$self->push_prefix(
		generic_command("item", "*\n"),
		blank_line(),
	);

	if ($type eq 'attribute') {
		if ($module_name eq $self->module_package()) {
			$self->push_body(
				text_paragraph(
					"Attribute L<$symbol|/$symbol> in this class.\n"
				),
			);
			return;
		}

		$self->push_body(
			text_paragraph(
				"L<$module_name|$module_name> " .
				"attribute \"L<$symbol|$module_name/$symbol>\".\n"
			)
		);
		return;
	}

	if ($type eq 'method') {
		if ($module_name eq $self->module_package()) {
			$self->push_body(
				text_paragraph(
					"Method L<$symbol|/$symbol> in this class.\n"
				)
			);
			return;
		}

		$self->push_body(
			text_paragraph(
				"L<$module_name|$module_name> " .
				"method L<$symbol()|$module_name/$symbol>.\n"
			)
		);
		return;
	}

	if ($type eq 'module') {
		$self->push_body(
			text_paragraph(
				"L<$module_name|$module_name> - " . $referent_module->abstract() . "\n"
			)
		);
		return;
	}

	die "xref type cannot be '$type'";
}


no Moose;

1;

package Pod::Plexus::Matter::boilerplate;

# TODO - Edit pass 0 done.

=abstract Define a reusable POD subsection.

=cut


=head1 SYNOPSIS

	=boilerplate section_body_handler

	[Z<>% SET command = c.match('::([a-z]+)').0 %]
	The POD associated with the "=[Z<>% command %]" command will be
	extracted and used as the body of any generated POD section.

	=cut

=cut


=head1 DESCRIPTION

[% m.package %] defines how Pod::Plexus will parse "=boilerplate"
meta-POD.  Boilerplates are sections of documentation that exist only
to be included elsewhere---usually several times over.  They don't
render to POD where they are defined.

=include boilerplate section_body_handler

=include Pod::Plexus::Matter boilerplate please_report_questions

=cut

use Moose;
extends 'Pod::Plexus::Matter::Directive';
with 'Pod::Plexus::Matter::Role::AbsorbedBody';


sub is_top_level { 1 }


has name => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		my $self = shift();

		my $element = $self->docs()->[ $self->docs_index() ];

		return $1 if $element->content() =~ /^\s* (\S+) \s*$/x;

		chomp(my $content = $element->content());
		die [
			"Wrong syntax" .
			" in '=" . $element->command() . " $content'" .
			" at " . $self->module_pathname() .
			" line " . $element->start_line()
		];
	},
);


# TODO - This tends to be common.
# How about abstracting it?
# Defining it as the default value in the base class?
has '+doc_suffix' => (
	default => sub {
		return [ blank_line(), cut_paragraph() ];
	},
);

# Doesn't render.
sub as_pod_elementals {
	return:
}


no Moose;

1;

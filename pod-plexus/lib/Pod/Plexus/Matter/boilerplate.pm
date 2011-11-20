package Pod::Plexus::Matter::boilerplate;

=abstract Define a reusable POD subsection.

=cut

=head1 DESCRIPTION

[% m.package %] defines how [% d.name %] will parse "=boilerplate"
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


sub is_inheritable { 1 }


has name => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		my $self = shift();

		my $element = $self->docs()->[ $self->docs_index() ];

		return $1 if $element->content() =~ /^\s* (\S+) \s*$/x;

		my $error = (
			"Wrong syntax: =" . $element->command() . " " . $element->content() .
			" at " . $self->module_path() .
			" line " . $element->start_line()
		);

		$self->push_error($error);
		return '(failed)';
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

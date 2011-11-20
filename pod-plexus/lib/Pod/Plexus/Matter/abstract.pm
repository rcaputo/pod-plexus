package Pod::Plexus::Matter::abstract;

# TODO - Edit pass 0 done.

=abstract Set a succinct, one-line description of the module.

=cut

=head1 SYNOPSIS

	package Pod::Plexus::Matter::abstract;

	=abstract Set a succinct, one-line description of the module.

	=cut

Renders as

	=head1 NAME

	Pod::Plexus::Matter::abstract - Set a succinct, one-line ....

	=cut

=cut

=head1 DESCRIPTION

[% m.package %] defines how [% d.name %] will parse "=abstract"
meta-POD and generate the resulting POD documentation.  Abstracts are
rewritten as "=head1 NAME" sections.

=include boilerplate section_body_handler

=include Pod::Plexus::Matter boilerplate please_report_questions

=cut

use Moose;
extends 'Pod::Plexus::Matter';
with 'Pod::Plexus::Matter::Role::HasNoBody';


use Pod::Plexus::Util::PodElemental qw(
	blank_line head_paragraph cut_paragraph text_paragraph
);


sub is_top_level { 1 }


=attribute abstract

The "[% s.name %]" attribute holds the abstract text used to build a
module's "=head1 NAME" section.  This value is also used by other
modules when cross referencing modules.

=cut

has abstract => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		my $self = shift();

		my $abstract = $self->docs()->[ $self->docs_index() ]->content();
		$abstract =~ s/^\s+//;
		$abstract =~ s/\s+$//;
		$abstract =~ s/\s+/ /g;

		return $abstract;
	},
);


=attribute doc_prefix

The "[% s.name %]" attribute defines how to begin the POD for
abstracts.

=example attribute doc_prefix

=cut

has '+doc_prefix' => (
	default => sub {
		return [ head_paragraph(1, "NAME\n"), blank_line() ];
	}
);


=attribute doc_body

"[% s.name %]" defines the abstract section's main POD.  It follows
the common style of "Package::Name - A succinct description."

=example attribute doc_body

=cut

has '+doc_body' => (
	lazy => 1,
	default => sub {
		my $self = shift;
		return [
			text_paragraph(
				$self->module_package() . " - " . $self->abstract() . "\n"
			),
		];
	},
);


=attribute doc_suffix

"[%s.name %]" documents a "=cut" paragraph to close the abstract's POD
section.

=cut

has '+doc_suffix' => (
	default => sub {
		return [ blank_line(), cut_paragraph() ];
	},
);


no Moose;

1;

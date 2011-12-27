package Pod::Plexus::Util::PodElemental;

# TODO - Edit pass 1 done.

=abstract Helper functions for generating and handling Pod::Elemental objects.

=cut

=head1 SYNOPSIS

This is a library of mostly unrelated functions.  There is no single
synopsis for the entire library.  Please see examples for each
function.

=cut

=head1 DESCRIPTION

[% m.package %] is a library of functions that perform common
Pod::Elemental tasks.  For example, it includes a function that builds
a standard '=head#' paragraph from basic parameters.

=cut

use warnings;
use strict;

use Pod::Elemental::Element::Generic::Blank;

use base 'Exporter';
our @EXPORT_OK = qw(
	blank_line text_paragraph head_paragraph generic_command
	cut_paragraph

	is_blank_paragraph

	cleanup_element_arrayref
);


=function is_blank_paragraph

[% s.name %](POD_ELEMENTAL_PARAGRPAH) tests whether a Pod::Elemental
paragraph consists entirely of zero or more blank lines.

=cut

sub is_blank_paragraph {
	return shift()->isa('Pod::Elemental::Element::Generic::Blank');
}


=function blank_line

[% s.name %]() generates a Pod::Elemental paragraph consisting of a
single blank line.  It's used to separate content paragraphs.

=cut

sub blank_line {
	return Pod::Elemental::Element::Generic::Blank->new(content => "\n");
}


=function text_paragraph

[% s.name %](LIST_OF_TEXT) generates a Pod::Elemental text paragraph
with the catenated contents of a LIST_OF_TEXT.  It's up to the caller
to provide newlines in appropriate places.

=cut

sub text_paragraph {
	return Pod::Elemental::Element::Generic::Text->new(content => join("", @_));
}


=function head_paragraph

[% s.name %](LEVEL, HEADING) generates a Pod::Elemental "headI<N>"
command paragraph, where I<N> is the heading LEVEL provided by the
caller.

	head_paragraph(2, "Public Methods")

would generate a Pod::Elemental::Element::Generic::Command that
renders to

	=head2 Public Methods

=cut

sub head_paragraph {
	my ($level, $heading) = @_;
	return generic_command("head$level", $heading);
}


=function generic_command

[% s.name %](COMMAND, CONTENT) creates a Pod::Elemental generic
command from a COMMAND name and the CONTENT following it on the same
line.

=example function head_paragraph

=cut

sub generic_command {
	my ($command, $content) = @_;
	return Pod::Elemental::Element::Generic::Command->new(
		command => $command,
		content => $content,
	);
}


=function cut_paragraph

[% s.name %]() creates a generic Pod::Elemental command that renders
to a "=cut" paragraph.

=example function cut_paragraph

=cut

sub cut_paragraph {
	return generic_command("cut", "\n");
}


=function cleanup_element_arrayref

[% s.name %](ARRAYREF_OF_POD_ELEMENTAL_PARAGRAPHS) performs basic
tidying operations.  It removes leading and trailing blank lines.  It
squashes consecutive blank lines into one.  It may do other things as
needed later.

=cut

sub cleanup_element_arrayref {
	my $elemental_arrayref = shift();

	shift @$elemental_arrayref while (
		@$elemental_arrayref and is_blank_paragraph($elemental_arrayref->[0])
	);

	pop @$elemental_arrayref while (
		@$elemental_arrayref and is_blank_paragraph($elemental_arrayref->[-1])
	);

	$_->content("\n") foreach (
		grep { is_blank_paragraph($_) }
		@$elemental_arrayref
	);

	my $i = @$elemental_arrayref - 1;
	while (--$i > 0) {
		if (is_blank_paragraph($elemental_arrayref->[$i])) {
			if (is_blank_paragraph($elemental_arrayref->[$i-1])) {
				splice(@$elemental_arrayref, $i, 1);
			}
			else {
				# Previous item isn't blank, so skip it, too.
				--$i;
			}
		}
	}
}


1;

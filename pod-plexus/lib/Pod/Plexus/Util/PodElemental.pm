package Pod::Plexus::Util::PodElemental;

# TODO - Edit pass 0 done.

=abstract Helper functions for generating and handling Pod::Elemental objects.

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


sub is_blank_paragraph {
	return shift()->isa('Pod::Elemental::Element::Generic::Blank');
}

sub blank_line {
	return Pod::Elemental::Element::Generic::Blank->new(content => "\n");
}

sub text_paragraph {
	return Pod::Elemental::Element::Generic::Text->new(content => join("", @_));
}

sub head_paragraph {
	my ($level, $content) = @_;
	return Pod::Elemental::Element::Generic::Command->new(
		command => "head$level",
		content => $content,
	);
}

sub generic_command {
	my ($command, $content) = @_;
	return Pod::Elemental::Element::Generic::Command->new(
		command => $command,
		content => $content,
	);
}

sub cut_paragraph {
	return Pod::Elemental::Element::Generic::Command->new(
		command => "cut",
		content => "\n",
	);
}

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
				# TODO - This needs some testing?
				--$i;
			}
		}
	}
}


1;

package Pod::Plexus::Util::PodElemental;

use warnings;
use strict;

use Pod::Elemental::Element::Generic::Blank;

use base 'Exporter';
our @EXPORT_OK = qw(
	blank_line text_paragraph head_paragraph generic_command
	cut_paragraph
);

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

1;

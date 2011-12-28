package Pod::Plexus::Matter::skip;
# TODO - Edit pass 1 done.

use Moose;
extends 'Pod::Plexus::Matter::Directive';
with 'Pod::Plexus::Matter::Role::HasNoBody';

use Pod::Plexus::Matter::skip::attribute;
use Pod::Plexus::Matter::skip::method;

use Carp qw(croak);


=abstract Tell Pod::Plexus that something shouldn't be documented.

=cut


=head1 SYNOPSIS

	=skip method BUILD

	=skip attribute verbose

	=cut

=cut


=boilerplate skip_purpose

Often a class may implement or inherit private methods that look
public because their names don't begin with underscores.  "=skip"
directives can eliminate these inadvertently public from the resulting
documentation.

=cut


=head1 DESCRIPTION

[% m.package %] implements the "=skip" directive, which tells
Pod::Plexus which symbols to skip when compiling and validating a
module's documentation.

=include boilerplate skip_purpose

=head2 Variants

=toc Pod::Plexus::Matter::skip::

=cut


=boilerplate new_from_element

[% s.name %]() creates a new [% m.package %]::attribute or
[% m.package %]::method object depending on Pod::Elemental command
syntax.

=cut


sub new_from_element {
	my ($class, %args) = @_;

	my $element = $args{element} // croak "element required";
	my $content = $element->content();
	chomp $content;

	if ($content =~ m/^\s* (attribute|method) \s+ (\S+) \s* $/x) {
		my ($type, $name) = ($1, $2);

		$class .= "::$type";
		return $class->new(%args, name => $name);
	}

	die [
		"Wrong syntax" .
		" in '=" . $element->command() . " $content'" .
		" at " . $args{module}->pathname() .
		" line " . $element->start_line()
	];
}


no Moose;

1;

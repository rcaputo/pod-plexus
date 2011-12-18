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

package Pod::Plexus::Matter::skip;

=abstract Tell Pod::Plexus that something shouldn't be documented.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Directive';

use Pod::Plexus::Matter::skip::attribute;
use Pod::Plexus::Matter::skip::method;

use Carp qw(croak);


has type => (
	is      => 'rw',
	isa     => 'Str',
	default => '',
);


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

	my $self = $class->new(%args);
	$self->push_error(
		"Wrong syntax: (=skip $content) " .
		" at " . $self->module_pathname() .
		" line " . $element->start_line()
	);

	return $self;
}


no Moose;

1;

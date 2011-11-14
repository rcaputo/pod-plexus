package Pod::Plexus::Matter::skip;

=abstract Handle directives that tell Pod::Plexus to skip things.

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


sub BUILD {
	my $self = shift();
	$self->discard_my_section();
}


no Moose;

1;

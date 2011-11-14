package Pod::Plexus::Matter::example;

=abstract A generic reference to a code example.

=cut

use Moose;
extends 'Pod::Plexus::Matter::Reference';

use Pod::Plexus::Matter::example::module;
use Pod::Plexus::Matter::example::attribute;
use Pod::Plexus::Matter::example::method;

use Pod::Plexus::Util::PodElemental qw(text_paragraph blank_line);

use Carp qw(confess);


has referent_name => (
	is  => 'ro',
	isa => 'Str',
);


has '+referent' => (
	isa     => 'Pod::Plexus::Module',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my $referent_name = $self->referent_name();
		my $referent = $self->module_distribution()->get_module($referent_name);
		return $referent if $referent;

		$self->push_error(
			"Unknown referent module ($referent_name) in =example" .
			" at " . $self->module_pathname() .
			" line " . $self->element()->start_line()
		);

		return;
	}
);


sub is_top_level { 0 }


sub new_from_element {
	my ($class, %args) = @_;

	my $element = $args{element} // confess "element required";
	my $content = $element->content();
	chomp $content;

	if ($content =~ m/^\s* (module) \s+ (\S+) \s*$/x) {
		my ($module_name, $type) = ($2, $1);
		$class .= "::$type";
		return $class->new(%args, referent_name => $module_name);
	}

	if ($content =~ m/^\s* (\S+) \s+ (attribute|method) \s+ (\S+) \s*$/x) {
		my ($module_name, $type, $name) = ($1, $2, $3);
		$class .= "::$type";
		return $class->new(%args, referent_name => $module_name, name => $name);
	}

	if ($content =~ m/^\s* (attribute|method) \s+ (\S+) \s* $/x) {
		my ($type, $name) = ($1, $2);
		$class .= "::$type";
		return $class->new(
			%args,
			referent_name => $args{module}->package(),
			name          => $name,
		);
	}

	my $self = $class->new(%args);
	$self->push_error(
		"Wrong syntax: (=example $content) " .
		" at " . $self->module_pathname() .
		" line " . $element->start_line()
	);
	return $self;
}


sub _is_local {
	my $self = shift();
	return $self->referent_name() eq $self->module_package();
}


=method beautify_code

[% ss.name %] beautifies the code passed to it in its only parameter.
Code is expected to be a single string containing multiple lines
separated by newlines.  A string of "beautified" multiple-line code is
returned.

=cut

sub beautify_code {
	my ($self, $code) = @_;

	# TODO - PerlTidy the code?
	# TODO - The following whitespace options are personal
	# preference.  Someone should patch them to be options.

	# Convert tab indents to fixed spaces for better typography.
	$code =~ s/\t/  /g;

	# Indent two spaces.  Remove leading and trailing blank lines.
	$code =~ s/\A(^\s*$)+//m;
	$code =~ s/(^\s*$)+\Z/\n/m;
	$code =~ s/^/  /mg;

	# Code must end in a newline.
	$code =~ s/\n*$/\n/;

	return $code;
}


sub _set_example {
	my ($self, $link, $code) = @_;
	$self->doc_body(
		[
			text_paragraph($link),
			blank_line(),
			text_paragraph( $self->beautify_code($code) )
		]
	);
}

no Moose;

1;

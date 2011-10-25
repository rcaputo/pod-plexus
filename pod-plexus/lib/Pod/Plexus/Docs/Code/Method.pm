package Pod::Plexus::Docs::Code::Method;

=abstract A reference to documentation for a class method.

=cut

use Moose;
extends 'Pod::Plexus::Docs::Code';


use constant POD_COMMAND  => 'method';


sub BUILD {
	my $self = shift();

	my ($module_name, $symbol_name) = $self->_parse_method_spec();

	return unless defined $module_name and length $module_name;

	$self->symbol($symbol_name);

	my $module = $self->library()->get_document($module_name);
	unless ($module) {
		push @{$self->errors()}, (
			"=method cannot find module $module_name" .
			" at " . $self->document()->pathname() .
			" line " .  $self->node()->{start_line}
		);
		return;
	}

	# TODO - At a late stage in the document writing, probably in
	# Pod::Plexus::Document, make sure (a) all implementations are
	# documented and (b) all documentation has an implementation.

	# TODO - Even better, see if some Dist::Zilla or Pod checker will do
	# it for us.

#	my $entity = $self->document()->_get_method($symbol_name);
#	unless ($entity) {
#		my $symbol = $self->node()->{content};
#		$symbol =~ s/\s+$//;
#
#		push @{$self->errors()}, (
#			"Cannot find implementation for '=method $symbol'" .
#			" at " . $self->document()->pathname() .
#			" line " .  $self->node()->{start_line}
#		);
#		return;
#	}

	$self->push_documentation(
		Pod::Elemental::Element::Generic::Command->new(
			command => "method",
			content => "$symbol_name\n",
		),
	);

	# Make a scratchpad entry in the class so we can find documentation.

	$self->document()->meta_entity()->add_method(
		"_pod_plexus_documents_method_$symbol_name\_" => sub { return $self },
	);
}


sub _parse_method_spec {
	my $self = shift();

	if ($self->node()->{content} =~ /^\s* (\S+) \s*$/x) {
		return($self->document()->package(), $1);
	}

	push @{$self->errors()}, (
		"Wrong syntax: =method " . $self->node()->{content} .
		" at " . $self->document()->pathname() .
		" line " . $self->node()->{start_line}
	);

	return;
}


no Moose;

1;

package Pod::Plexus::Reference::Include;

=abstract A reference to documentation included from elsewhere.

=cut

use Moose;
extends 'Pod::Plexus::Reference';


has '+symbol' => (
	default => "",
);


use constant POD_COMMAND  => 'include';


sub BUILD {
	my $self = shift();

	my ($module, $type, $symbol) = $self->_parse_include_spec();

	return unless $module;

	my $foreign_document = $self->library()->get_document($module);
	$foreign_document->prepare_to_render($self->errors());
	return if @{$self->errors()};

	my $foreign_reference = $foreign_document->get_reference(
		$type, $module, $symbol
	);

	$self->push_documentation(@{$foreign_reference->body()});
	$self->cleanup_documentation();
}


sub _parse_include_spec {
	my $self = shift();

	my %type_class = (
		'attribute' => 'Pod::Plexus::Reference::Entity::Attribute',
		'method'    => 'Pod::Plexus::Reference::Entity::Method',
	);

	if (
		$self->node()->{content} =~ m{
			^\s* (\S*) \s+ (attribute|method) \s+ (\S.*?) \s*$
		}x
	) {
		return($1, $type_class{$2}, $3);
	}

	if (
		$self->node()->{content} =~ m!^\s* (attribute|method) \s+ (\S.*?) \s*$!x
	) {
		return($self->document()->package(), $type_class{$1}, $2);
	}

	push @{$self->errors()}, (
		"Wrong inclusion syntax: =include " . $self->node()->{content} .
		" at " . $self->document()->pathname() .
		" line " . $self->node()->{start_line}
	);

	return;
}


no Moose;

1;

package Pod::Plexus::Reference;

use Moose;
with 'Pod::Plexus::Role::Documentable';

has key => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();
		return $self->calc_key(ref($self), $self->module(), $self->symbol());
	},
);

sub calc_key {
	(undef, my ($type, $module, $symbol)) = @_;
	$symbol //= "";
	return join("\t", $type, $module, ($symbol // ""));
}

has invoked_in => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has module => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has symbol => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

sub is_local {
	my $self = shift();
	return $self->invoked_in() eq $self->module();
}

no Moose;

1;

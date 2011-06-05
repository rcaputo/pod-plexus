package Pod::Plexus::Document;

use Moose;
use PPI;
use Pod::Elemental;

use feature 'switch';

use PPI::Lexer;
$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';

has pathname => ( is => 'ro', isa => 'Str', required => 1 );

has library => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Library',
	required => 1,
	weak_ref => 1,
);

has ppi => (
	is      => 'ro',
	isa     => 'PPI::Document',
	lazy    => 1,
	default => sub { PPI::Document->new( shift()->pathname() ) },
);

has extends => (
	is       => 'rw',
	isa      => 'HashRef[Str]',
	traits   => [ 'Hash' ],
	handles  => {
		has_base => 'exists',
		add_base => 'set',
		get_base => 'get',
	},
);

has consumes => (
	is       => 'rw',
	isa      => 'HashRef[Str]',
	traits   => [ 'Hash' ],
	handles  => {
		has_role => 'exists',
		add_role => 'set',
		get_role => 'get',
	},
);

has elemental => (
	is      => 'ro',
	isa     => 'Pod::Elemental::Document',
	lazy    => 1,
	default => sub { Pod::Elemental->read_file( shift()->pathname() ) },
);

has template => (
	is       => 'ro',
	isa      => 'Template',
	required => 1,
);

### Public accessors!

has module => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my $main_package = $self->ppi()->find_first('PPI::Statement::Package');
		return "" unless $main_package;

		return $main_package->namespace();
	},
);

has abstract => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();

		use Pod::Elemental::Selectors qw(s_command);

		my $children = $self->elemental()->children();
		my $commands = s_command('abstract');

		my @abstract_index;

		for my $i (0 .. $#$children) {
			next unless $commands->( $children->[$i] );
			push @abstract_index, $i;
		}

		die $self->module(), " has no abstract" unless @abstract_index;
		die $self->module(), " has too many abstracts" if @abstract_index > 1;

		# Remove it.
		my $abstract = splice( @$children, $abstract_index[0], 1 );

		return $abstract->content();
	},
);

sub code {
	my $self = shift();

	my $out = $self->ppi()->clone();
	$out->prune('PPI::Statement::End');
	$out->prune('PPI::Statement::Data');
	$out->prune('PPI::Token::Pod');

	return $out->serialize();
}

sub sub {
	my ($self, $sub_name) = @_;

	my $subs = $self->ppi()->find(
		sub {
			$_[1]->isa('PPI::Statement::Sub') and
			defined($_[1]->name()) and
			$_[1]->name() eq $sub_name
		}
	);

	die $self->module(), " doesn't define sub $sub_name" unless @$subs;
	die $self->module(), " defines too many subs $sub_name" if @$subs > 1;

	return $subs->[0]->content();
}

### End public accessors!

sub BUILD {
	warn "Absorbing ", shift()->pathname(), " ...\n";
}

sub render {
	my $self = shift();

	my $elemental = $self->elemental();

	# TODO - I can see why autoboxing is sexy.

	my $input = "";
	my @queue = @{$self->elemental()->children()};
	while (@queue) {
		my $next = shift @queue;
		$input .= $next->as_pod_string();

		next unless $next->can("children");
		my $sub_children = $next->children();
		unshift @queue, @$sub_children if @$sub_children;
	}

	my $output = "";

	my %vars = (
		doc => $self,
		lib => $self->library(),
	);

	$self->template()->process(\$input, \%vars, \$output) or die(
		$self->template()->error()
	);

	return $output;
}

sub elementaldump {
	my $self = shift();
	use YAML;
	print YAML::Dump($self->elemental());
	exit;
}

sub ppidump {
	my $self = shift();
	use PPI::Dumper;
	my $d = PPI::Dumper->new( $self->ppi() );
	$d->print();
	exit;
}

sub collect_ancestry {
	my $self = shift();

	my $ppi = $self->ppi();

	my $includes = $ppi->find(
		sub {
			$_[1]->isa('PPI::Statement::Include') or (
				$_[1]->isa('PPI::Statement') and
				$_[1]->child(0)->isa('PPI::Token::Word') and
				$_[1]->child(0)->content() eq 'extends'
			)
		}
	);

	foreach (@$includes) {
		my $type = $_->child(0)->content();

		# Remove "type".
		my @children = $_->children();
		splice(@children, 0, 1);

		my @stuff;
		foreach (@children) {
			if ($_->isa('PPI::Token::Word')) {
				push @stuff, $_->content();
				next;
			}

			if ($_->isa('PPI::Structure::List')) {
				push @stuff, map { $_->string() } @{ $_->find('PPI::Token::Quote') };
				next;
			}

			if ($_->isa('PPI::Token::QuoteLike::Words')) {
				push @stuff, $_->literal();
				next;
			}

			if ($_->isa('PPI::Token::Quote')) {
				push @stuff, $_->string();
				next;
			}

			# Ignore the others.
		}

		given ($type) {
			when ('use') {
				# TODO - What do we care?
			}
			when ('extends') {
				$self->add_base($_, 1) foreach @stuff;
			}
			when ('with') {
				$self->add_role($_, 1) foreach @stuff;
			}
			default {
				die "odd type '$type'";
			}
		}
	}
}

sub expand_commands {
	my $self = shift();

	my $doc = $self->elemental();

	my $i = @{ $doc->children() };
	NODE: while ($i--) {

		my $node = $doc->children->[$i];

		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		### "=for example (spec)" -> code example sourced from (spec).

		if (
			$node->{command} eq 'for' and
			$node->{content} =~ /^\s*example\s+(\S.*?)\s*$/
		) {
			my (@args) = split(/\s+/, $1);

			die "too many args for example" if @args > 2;
			die "not enough args for example" if @args < 1;

			my ($link, $content);
			if (@args == 2) {
				$link = (
					"This is L<$args[0]|$args[0]> " .
					"sub L<$args[1]()|$args[0]/$args[1]>.\n\n"
				);
				$content = $self->library()->get_module($args[0])->sub($args[1]);
			}
			elsif ($args[0] =~ /:/) {
				$link = "This is L<$args[0]|$args[0]>.\n\n";
				$content = $self->library()->get_module($args[0])->code();
			}
			else {
				$link = "This is L<$args[0]()|/$args[0]>.\n\n";
				$content = $self->sub($args[0]);
			}

			# Indent two spaces.  Remove leading and trailing blank lines.
			# TODO - Better indenting for things that are already indented.
			$content =~ s/\A(^\s*$)+//m;
			$content =~ s/(^\s*$)+\Z//m;
			$content =~ s/^/  /mg;

			splice(
				@{$doc->children()}, $i, 1,
				Pod::Elemental::Element::Generic::Text->new(
					content => $link . $content,
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
			);

			next NODE;
		}

		### "=abstract (text)" -> "=head1 NAME\n\n(module) - (text)\n\n".

		if ($node->{command} eq 'abstract') {
			splice(
				@{$doc->children()}, $i, 1,
				Pod::Elemental::Element::Generic::Command->new(
					command => "head1",
					content => "NAME\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Text->new(
					content => $self->module() . " - " . $node->content()
				),
			);
			next NODE;
		}

		### "=copyright (years) (whom)" -> "=head1 COPYRIGHT AND LICENSE"
		### boilerplate.

		if ($node->{command} eq 'copyright') {
			my ($year, $whom) = ($node->{content} =~ /^\s*(\S+)\s+(.*?)\s*$/);

			splice(
				@{$doc->children()}, $i, 1,
				Pod::Elemental::Element::Generic::Command->new(
					command => "head1",
					content => "COPYRIGHT AND LICENSE\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						$self->module() . " is Copyright $year by $whom\n" .
						"All rights are reserved.\n" .
						$self->module() .
						" is released under the same terms as Perl itself.\n"
					),
				),
			);

			next NODE;
		}
	}
}

no Moose;

1;

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
	is      => 'rw',
	isa     => 'Str',
	lazy    => 1,
	default => sub { confess "no abstract found" },
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
		module => $self->module(),
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

sub collect_data {
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

	foreach (@{$includes || []}) {
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
			when ('no') {
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

	NODE: foreach my $node (@{ $self->elemental()->children() }) {
		next NODE unless $node->isa('Pod::Elemental::Element::Generic::Command');

		if ($node->{command} eq 'abstract') {
			$self->abstract( $node->content() );
			next NODE;
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

		### "=example (spec)" -> code example sourced from (spec).

		if ($node->{command} eq 'example') {
			my (@args) = split(/\s+/, $node->{content});

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
				# TODO - We're trying to omit the "This is" link if the
				# content includes an obvious package name.  There may be a
				# better way to do this, via PPI for example.

				$content = $self->library()->get_module($args[0])->code();
				if ($content =~ /^\s*package/) {
					$link = "";
				}
				else {
					$link = "This is L<$args[0]|$args[0]>.\n\n";
				}
			}
			else {
				$link = "This is L<$args[0]()|/$args[0]>.\n\n";
				$content = $self->sub($args[0]);
			}

			# TODO - PerlTidy the code?
			# TODO - The following whitespace options are personal
			# preference.  Someone should patch them to be options.

			# Indent two spaces.  Remove leading and trailing blank lines.
			$content =~ s/\A(^\s*$)+//m;
			$content =~ s/(^\s*$)+\Z//m;
			$content =~ s/^/  /mg;

			# Convert tab indents to fixed spaces for better typography.
			$content =~ s/\t/  /g;

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

		### "=xref (module)" -> "=item *\n\n(module) - (its abstract)"
		#
		# TODO - Collect them without rendering.  Add them to a SEE ALSO
		# section.

		if ($node->{command} eq 'xref') {
			my $module = $node->{content};
			$module =~ s/^\s+//;
			$module =~ s/\s+$//;

			splice(
				@{$doc->children()}, $i, 1,
				Pod::Elemental::Element::Generic::Command->new(
					command => "item",
					content => "*\n",
				),
				Pod::Elemental::Element::Generic::Blank->new(
					content => "\n",
				),
				Pod::Elemental::Element::Generic::Text->new(
					content => (
						"L<$module|$module> - " .
						$self->library()->module($module)->abstract()
					),
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
					content => $self->module() . " - " . $self->abstract()
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
						$self->module() . " is Copyright $year by $whom.\n" .
						"All rights are reserved.\n" .
						$self->module() .
						" is released under the same terms as Perl itself.\n"
					),
				),
			);

			next NODE;
		}

		# Index modules in the library that match a given regular
		# expression.  Dangerous, but we're all friends here, right?

		if ($node->{command} =~ /^index(\d*)/) {
			my $level = $1 || 2;

			(my $regexp = $node->{content} // "") =~ s/\s+//g;
			$regexp = "^" . $self->module() . "::" unless length $regexp;

			my @insert = (
				map {
					Pod::Elemental::Element::Generic::Command->new(
						command => "item",
						content => "*\n",
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
					Pod::Elemental::Element::Generic::Text->new(
						content => (
							"L<$_|$_> - " .
							$self->library()->module($_)->abstract()
						),
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
				}
				sort
				grep /$regexp/, $self->library()->get_module_names()
			);

			unless (@insert) {
				@insert = (
					Pod::Elemental::Element::Generic::Command->new(
						command => "item",
						content => "*\n",
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
					Pod::Elemental::Element::Generic::Text->new(
						content => "No modules match /$regexp/"
					),
					Pod::Elemental::Element::Generic::Blank->new(
						content => "\n",
					),
				);
			}

			splice( @{$doc->children()}, $i, 1, @insert );

			next NODE;
		}

		### "=include MODULE SECTION" -> documentation copied from source.
		#
		# TODO - Need to ensure the full rendering of source material
		# before inserting it here.

		if ($node->{command} eq 'include') {
			my @args = split(/\s+/, $node->{content});

			die "too many args for include" if @args > 2;
			die "not enough args for include" if @args < 2;

			my ($module_name, $section) = @args;

			my $source_module = $self->library()->get_module($module_name);

			die "unknown module $module_name in include" unless $source_module;

			my $source_doc = $source_module->elemental();

			my $closing_command;
			my @insert;

			SOURCE_NODE: foreach my $source_node (@{ $source_doc->children() }) {

				unless (
					$source_node->isa('Pod::Elemental::Element::Generic::Command')
				) {
					push @insert, $source_node if $closing_command;
					next SOURCE_NODE;
				}

				if ($closing_command) {
					last SOURCE_NODE if $source_node->{command} eq $closing_command;

					push @insert, $source_node;
					next SOURCE_NODE;
				}

				next unless $source_node->{content} =~ /^\Q$section\E/;

				$closing_command = $source_node->{command};
			}

			die "Couldn't find =insert $module_name $section" unless @insert;

			# Trim blanks around a section of Pod::Elemental nodes.
			# TODO - Make a helper method.
			shift @insert while (
				@insert and $insert[0]->isa('Pod::Elemental::Element::Generic::Blank')
			);
			pop @insert while (
				@insert and $insert[-1]->isa('Pod::Elemental::Element::Generic::Blank')
			);

			splice( @{$doc->children()}, $i, 1, @insert );

			next NODE;
		}
	}
}

no Moose;

1;

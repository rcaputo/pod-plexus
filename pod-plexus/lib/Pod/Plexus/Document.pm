package Pod::Plexus::Document;

use Moose;
use PPI;
use Pod::Elemental;
use Devel::Symdump;

use Pod::Plexus::Entity::Method;
use Pod::Plexus::Entity::Attribute;

use feature 'switch';

use PPI::Lexer;
$PPI::Lexer::STATEMENT_CLASSES{with} = 'PPI::Statement::Include';

has pathname => ( is => 'ro', isa => 'Str', required => 1 );

=doc library

[% ss.name %] contains the Pod::Plexus::Library object that represents
the entire library of documents.  The current Pod::Plexus::Document
object is included.

=cut

has library => (
	is       => 'ro',
	isa      => 'Pod::Plexus::Library',
	required => 1,
	weak_ref => 1,
);

=doc _ppi

[% ss.name %] contains a PPI::Document representing parsed module
being documented.  [% mod.package %] uses this to find source code to
include in the documentation, examine the module's implementation for
documentation clues, and so on.

=cut

has _ppi => (
	is      => 'ro',
	isa     => 'PPI::Document',
	lazy    => 1,
	default => sub { PPI::Document->new( shift()->pathname() ) },
);

=doc _elemental

[% ss.name %] contains a Pod::Elemental::Document representing the
parsed POD from the module being documented.  [% mod.package %]
documents modules by inspecting and revising [% ss.name %], among
other things.

=cut

has elemental => (
	is      => 'ro',
	isa     => 'Pod::Elemental::Document',
	lazy    => 1,
	default => sub { Pod::Elemental->read_file( shift()->pathname() ) },
);

=doc extends

TODO

=cut

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

=doc consumes

TODO

=cut

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

=doc _template

[% lib.main_module %] expands documentation using Template Toolkit.
[% ss.name %] contains a Template object used to expand variables in
the documentation.

=cut

has _template => (
	is       => 'ro',
	isa      => 'Template',
	required => 1,
);

=doc package

[% ss.name %] contains the module's main package name.  Its main use
is in template expansion, via the "mod.package" expression.

=cut

has package => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my $main_package = $self->_ppi()->find_first('PPI::Statement::Package');
		return "" unless $main_package;

		return $main_package->namespace();
	},
);

=doc abstract

TODO

=cut

has abstract => (
	is      => 'rw',
	isa     => 'Str',
	lazy    => 1,
	default => sub { confess "no abstract found" },
);

=doc attributes

TODO

=cut

has attributes => (
	is      => 'rw',
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Entity::Attribute]',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my %entities;

		foreach ($self->mop_class()->get_all_attributes()) {
			my $name = $_->name();
			die "$name used more than once" if exists $entities{$name};
			$entities{$name} = Pod::Plexus::Entity::Attribute->new(
				mop_entity => $_,
				name       => $name,
			);
		}

		return \%entities;
	},
);

=doc methods

TODO

=cut

has methods => (
	is      => 'rw',
	is      => 'rw',
	isa     => 'HashRef[Pod::Plexus::Entity::Method]',
	lazy    => 1,
	default => sub {
		my $self = shift();

		my %entities;
		my $skip_methods = $self->skip_methods();

		foreach ($self->mop_class()->get_all_methods()) {
			my $name = $_->name();
			next if exists $skip_methods->{$name};
			die "$name used more than once" if exists $entities{$name};
			$entities{$name} = Pod::Plexus::Entity::Method->new(
				mop_entity => $_,
				name       => $name,
			);
		}

		return \%entities;
	},
);

=doc mop_class

TODO

=cut

has mop_class => (
	is => 'rw',
	isa => 'Class::MOP::Class',
	lazy => 1,
	default => sub {
		my $self = shift();

		my $class_name = $self->package();
		return unless $class_name;

		# Must be loaded to be introspected.
		Class::MOP::load_class($class_name);
		return Class::MOP::Class->initialize($class_name);
	},
);

=doc skip_methods

TODO

=cut

has skip_methods => (
	is => 'ro',
	isa => 'HashRef',
	default => sub {
		{
			meta        => 1,
			BUILDARGS   => 1,
			BUILDALL    => 1,
			DEMOLISHALL => 1,
			does        => 1,
			DOES        => 1,
			dump        => 1,
			can         => 1,
			VERSION     => 1,
			DESTROY     => 1,
		}
	},
);

=doc code

TODO

=cut

sub code {
	my $self = shift();

	my $out = $self->_ppi()->clone();
	$out->prune('PPI::Statement::End');
	$out->prune('PPI::Statement::Data');
	$out->prune('PPI::Token::Pod');

	return $out->serialize();
}

=doc sub

TODO

=cut

sub sub {
	my ($self, $sub_name) = @_;

	my $subs = $self->_ppi()->find(
		sub {
			$_[1]->isa('PPI::Statement::Sub') and
			defined($_[1]->name()) and
			$_[1]->name() eq $sub_name
		}
	);

	die $self->package(), " doesn't define sub $sub_name" unless @$subs;
	die $self->package(), " defines too many subs $sub_name" if @$subs > 1;

	return $subs->[0]->content();
}

### End public accessors!

sub BUILD {
	warn "Absorbing ", shift()->pathname(), " ...\n";
}

=doc render

TODO

=cut

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
		module => $self->package(),
	);

	$self->_template()->process(\$input, \%vars, \$output) or die(
		$self->_template()->error()
	);

	return $output;
}

=doc elementaldump

TODO

=cut

sub elementaldump {
	my $self = shift();
	use YAML;
	print YAML::Dump($self->elemental());
	exit;
}

=doc ppidump

TODO

=cut

sub ppidump {
	my $self = shift();
	use PPI::Dumper;
	my $d = PPI::Dumper->new( $self->_ppi() );
	$d->print();
	exit;
}

=doc collect_data

TODO

=cut

sub collect_data {
	my $self = shift();

	my $ppi = $self->_ppi();

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
				# TODO - What do we care?  Probably so, if it's "use base".
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

	# Shamelessly "adapted" from Pod::Weaver::Section::ClassMopper 0.02.

	while (my ($name, $ent) = each %{$self->attributes()}) {
		warn(
			$self->package(), " - ",
			($ent->private() ? "private" : "public"), " attribute $name\n",
		);
	}

	while (my ($name, $ent) = each %{$self->methods()}) {
		warn(
			$self->package(), " - ",
			($ent->private() ? "private" : "public"), " method $name\n",
		);
	}
}

=doc expand_commands

TODO

=cut

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

				if ($args[0] =~ /\//) {
					# Reference by path.
					# TODO - Reliance on / as path separator sucks.
					$content = $self->library()->_get_document($args[0])->sub($args[1]);
				}
				else {
					# Assume it's a module name.
					$content = $self->library()->get_module($args[0])->sub($args[1]);
				}
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
			elsif ($args[0] =~ /[\/.]/) {
				# Reference by path doesn't omit the "This is" link.
				# It's intended to be used with executable programs.

				$content = $self->library()->_get_document($args[0])->code();
				$link = "This is L<$args[0]|$args[0]>.\n\n";
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
						$self->library()->package($module)->abstract()
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
					content => $self->package() . " - " . $self->abstract()
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
						$self->package() . " is Copyright $year by $whom.\n" .
						"All rights are reserved.\n" .
						$self->package() .
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
			$regexp = "^" . $self->package() . "::" unless length $regexp;

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
							$self->library()->package($_)->abstract()
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
					# TODO - What other conditions close an element?

					last SOURCE_NODE if (
						$source_node->{command} eq $closing_command or
						$source_node->{command} eq 'cut'
					);

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

__END__

=pod

=abstract Represent and render a single Pod::Plexus document.


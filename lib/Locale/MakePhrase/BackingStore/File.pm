package Locale::MakePhrase::BackingStore::File;
our $VERSION = 0.1;
our $DEBUG = 0;

=head1 NAME

Locale::MakePhrase::BackingStore::File - Retrieve language
translations for all supported languages, from a single file.

=head1 DESCRIPTION

This backing store is capable of loading language rules from a
translation file.

The file must be formatted as shown in the B<example.txt> file (which
can be located in the same directories that these modules are are
installed in).  The important points to note are that the file is
broken into groups containing:

=over 2

=item B<key>

=item B<language/dialect>

=item B<expression>

=item B<priority>

=item B<translation>

Where expression & priority are optional.  However, if you specify the
priority and/or expression, make sure the translation key is the last
entry in the group (see L<TODO>).

=back

=head1 API

The following functions are implemented:

=cut

use strict;
use warnings;
use utf8;
use Data::Dumper;
use base qw(Locale::MakePhrase::BackingStore);
use I18N::LangTags;
use Locale::MakePhrase::Utils qw(die_from_caller alltrim);
our $implicit_data_structure = [ "key","language","expression","priority","translation" ];
our $default_encoding = 'utf-8';
$Data::Dumper::Indent = 1 if $DEBUG;

#--------------------------------------------------------------------------

=head2 $self init([...])

We support loading text/translations (from the translation file) which
may be encoded using any character encoding.  Since we need to know
something about the file we are trying to load, we expect this object
to be constructed with the following options:

=over 2

=item C<file>

The full path to the file containing the translations. eg:

  /usr/local/myapp/translations.mpt

=item C<encoding>

We can load translations from any enocding supported by the L<Encode>
module.  Upon load, this module will convert the translations from
the specified encoding, into the interal encoding of UTF-8.

Default: load UTF-8 encoded text translations.

=item C<dont_reload>

It is handy for the language module to be able to dynamically reload
its known translations, if the file gets updated.  You can set this
to avoid reloading the file if it changes.

Default: reload if file changes

=back

=cut

sub init {
  my $self = shift;

  # get options
  my %options;
  if (@_ > 1 and not(@_ % 2)) {
    %options = @_;
  } elsif (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } elsif (@_ == 1) {
    $options{file} = shift;
  } else {
    die_from_caller("Invalid arguments passed to new()");
  }
  print STDERR "Arguments to ". ref($self) .": ". Dumper(\%options) if $DEBUG > 5;
  die_from_caller("Missing 'file' argument") unless $options{file};
  $self->{file} = $options{file};
  $self->{rules} = {};
  $self->{mtime} = 0;
  $self->{encoding} = $default_encoding;
  $self->{encoding} = $options{encoding} if (exists $options{encoding});
  $self->{dont_reload} = $options{dont_reload} ? 1 : 0;

  # make sure file exists
  die_from_caller("No such file:",$self->{file}) unless (-e $self->{file});

  # Pre-load all available languages
  $self->_load_file();

  return $self;
}

#--------------------------------------------------------------------------

=head2 \@rule_objs get_rules($context,$key,\@languages)

Retrieve the translations (that have been previously loaded), using the
selected languages.  This implementation will reload the language file
if it changes (unless it has been told not to).

=cut

sub get_rules {
  my ($self,$context,$key,$languages) = @_;
  my @translations;

  # make sure languages are loaded
  $self->_load_file() unless $self->{dont_reload};

  # look for rules for each language in the current key
  my @langs;
  my $rules = $self->{rules};
print Dumper($rules);
  foreach my $language (@$languages) {
    next unless (exists $rules->{$language});
    push @langs, $rules->{$language};
  }
  return undef unless @langs;
  $rules = undef;

  # Only use rules which match this context, if we are using a context
  if ($context) {

    # look for rules that match the key
    foreach my $language (@langs) {
      my $keys = $language->{$key};
      next unless ($keys or ref($keys) ne 'HASH');
      $keys = $keys->{$context};
      next unless $keys;
      foreach my $ky (@$keys) {
        push @translations, $ky;
      }
    }

  } else {

    # look for rules that match the key
    foreach my $language (@langs) {
      my $keys = $language->{$key};
      next unless $keys;
      $keys = $keys->{_};
      foreach my $ky (@$keys) {
        push @translations, $ky;
      }
    }

  }

  print STDERR "Found translations:\n", Dumper(@translations) if $DEBUG;
  return \@translations;
}

#--------------------------------------------------------------------------
#
# If the file hasn't yet been loaded or its mtime has changed, load it into the cache.
#
sub _load_file {
  my ($self) = @_;
  my $file = $self->{file};
  die_from_caller("Incorrect permissions on translation file:",$file) unless ((-f $file || -l $file) and -r $file);

  # if mtime is same as previous, do nothing
  my $mtime = (stat($file))[9];
  return if ($mtime == $self->{mtime});

  # ... mtime has changed -> reload the file
  $self->{mtime} = $mtime;
  $self->{rules} = undef;

  # Load the translations from the file (skip empty lines, or comments)
  my $rules = {};
  my ($key,$language,$expression,$priority,$translation,$context);
  my $in_group = 0;
  my $line = 0;
  my $encoding = $self->{encoding};
  open (FH, "<:encoding($encoding)", "$file") || die_from_caller("Failed to open translation file:",$file);

  while (<FH>) {
    chomp;
    $line++;
    $_ = alltrim($_);
    next if (not defined or length == 0 or /^#/);

    # search for group entries
    /^
      ([^=]*)=(.*)
      |
      (.*)
     $/sx;
    next unless ($1);
    my $lhs = alltrim($1);
    my $rhs = alltrim($2);

    # process group entries
    if ($lhs eq 'key') {
      die_from_caller("Found another group while processing previous group, file '$file' line '$line'") if ($in_group);
      $in_group++;
      $key = $rhs;
      die_from_caller("Key must have some length, file '$file' line '$line'") unless (length $key);
      next;
    } elsif ($lhs eq 'language' and not defined $language) {
      $language = $rhs;
      $language =~ tr<_A-Z><-a-z>; # support the variations case/hyphenation for language/locale
      die_from_caller("Language must have some length, file '$file' line '$line'") unless (length $language);
      die_from_caller("Must be valid language tag, file '$file' line '$line'") unless (I18N::LangTags::is_language_tag($language));
      $language =~ tr<-><_>;
    } elsif ($lhs eq 'expression' and not defined $expression) {
      $expression = $rhs;
    } elsif ($lhs eq 'priority' and not defined $priority) {
      $priority = $rhs;
      $priority = int($priority); # must be a valid number
    } elsif ($lhs eq 'translation' and not defined $translation) {
      $translation = $rhs;
      die_from_caller("Translation must have some length, file '$file' line '$line'") unless (length $translation);
    } elsif ($lhs eq 'context' and not defined $context) {
      $context = $rhs;
    } else {
      die_from_caller("Syntax error in translation file '$file', line '$line'");
    }

    # Have we enough info to make a linguistic rule?
    next unless (defined $language and $translation);
    $expression = "" unless $expression;
    $priority = 0 unless $priority;
    $context = "" unless $context;

    # Make this linguistic rule, and add it to any others that may exist for this language/key
    $in_group--;
    my $entries;
    if ($context) {
      $entries = $rules->{$language}{$key}{$context};
      unless ($entries) {
        $entries = [] unless $entries;
        $rules->{$language}{$key}{$context} = $entries;
      }
    } else {
      $entries = $rules->{$language}{$key}{_};
      unless ($entries) {
        $entries = [] unless $entries;
        $rules->{$language}{$key}{_} = $entries;
      }
    }
    push @$entries, $self->make_rule(
      key => $key,
      language => $language,
      expression => $expression,
      priority => $priority,
      translation => $translation,
    );

    $key = $language = $expression = $priority = $translation = $context = undef;
  }

  close FH;
  $self->{rules} = $rules;
}

1;
__END__
#--------------------------------------------------------------------------

=head1 TODO

Need to re-implement file parser to allow the syntax of the file to be a
little more flexible / user-friendly.

=cut


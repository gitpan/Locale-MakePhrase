package Locale::MakePhrase::BackingStore::Directory;
our $VERSION = 0.1;
our $DEBUG = 0;

=head1 NAME

Locale::MakePhrase::BackingStore::Directory - Retrieve translations
from files located in specified directory.

=head1 DESCRTIPION

This backing store is capable of loading language rules, from files
located in the specified directory.  All files ending with the
extension B<.mpt> will try to be loaded.

Files need to be named according to language/dialect. For example:

  en.mpt
  en_au.mpt
  cn.mpt

Thus, the filename is used to defined the I<language> component of
the language rule object.

The files must be formatted as shown in the B<en.mpt-example> and
B<cn.mpt-example> files (which can be located in the same directories
that these modules are are installed in).  The important points to
note are that the file is broken into groups containing:

=over 2

=item B<key>

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
use Locale::MakePhrase::Utils qw(alltrim die_from_caller);
our $implicit_data_structure = [ "key","expression","priority","translation" ];
our $language_file_extension = '.mpt';  # .mpt => 'MakePhrase Translations'
our $default_encoding = 'utf-8';
$Data::Dumper::Indent = 1 if $DEBUG;

#--------------------------------------------------------------------------

=head2 $self init([...])

We support loading text/translations (from the translation files) which
may be encoded using any character encoding.  Since we need to know
something about the files we are trying to load, we expect this object
to be constructed with the following options:

=over 2

=item C<directory>

The full path to the directory containing the translation files. eg:

  /usr/local/myapp/translations

Default file extension: .mpt

=item C<encoding>

We can load translations from any enocding supported by the L<Encode>
module.  Upon load, this module will convert the translations from
the specified encoding, into the interal encoding of UTF-8.

Default: load UTF-8 text translations.

=item C<dont_reload>

It is handy for the language module to be able to dynamically reload
its known translations, if the files get updated.  You can set this
to avoid reloading the file if it changes.

Default: reload language file if changed

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
    $options{directory} = shift;
  } else {
    die_from_caller("Invalid arguments passed to new()");
  }
  print STDERR "Arguments to ". ref($self) .": ". Dumper(\%options) if $DEBUG > 5;
  die_from_caller("Missing 'directory' argument") unless $options{directory};
  $self->{directory} = $options{directory};
  $self->{loaded_languages} = {};
  $self->{rules} = {};
  $self->{encoding} = $default_encoding;
  $self->{encoding} = $options{encoding} if (exists $options{encoding});
  $self->{dont_reload} = $options{dont_reload} ? 1 : 0;

  # make sure directory exists
  die_from_caller("No such directory:",$self->{directory}) unless (-d $self->{directory});

  # Pre-load all available languages
  $self->_load_language_files();

  return $self;
}

#--------------------------------------------------------------------------

=head2 \@rule_objs get_rules($context,$key\@languages)

Retrieve the translations (that have been previously loaded), using
the selected languages.  This implementation will reload the
appropiate language file if it changes (unless it has been told not
to).

=cut

sub get_rules {
  my ($self,$context,$key,$languages) = @_;
  my @translations;

  # make sure languages are loaded
  $self->_load_languages($languages) unless $self->{dont_reload};

  # look for rules for each language in the current key
  my @langs;
  my $rules = $self->{rules};
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
# Load all the available language files (can end with extension '.mpt')
#
sub _load_language_files {
  my ($self) = @_;
  my $dir = $self->{directory};
  die_from_caller("Directory is not readable:",$dir) unless (-r $dir);
  opendir(DIR, $dir) or die_from_caller("Failed to read into directory:",$dir);
  my @files = readdir(DIR);
  closedir DIR;
  foreach my $language (@files) {
    next unless ($language =~ /$language_file_extension$/);
    next unless ((-f "$dir/$language" || -l "$dir/$language") and -r "$dir/$language");
    $language =~ s/$language_file_extension//o;
    next unless I18N::LangTags::is_language_tag($language);
    $self->_load_language($language);
  }
}

#--------------------------------------------------------------------------
#
# Load the translations for each language.
#
# If the file for that language hasn't yet been loaded or its mtime has changed,
# load it into the cache.
#
# If the cached language is valid, dont do anything.
#
sub _load_languages {
  my ($self,$languages) = @_;
  my $loaded_languages = $self->{loaded_languages};
  my $rules = $self->{rules};
  foreach my $language (@$languages) {
    if (exists $loaded_languages->{$language}) {
      my $file = $loaded_languages->{$language}->{file};
      my $mtime = (stat($file))[9];
      next if ($loaded_languages->{$language}->{mtime} == $mtime);
      $rules->{$language} = undef;
    }
    $self->_load_language($language);
  }
}

#--------------------------------------------------------------------------
#
# Load the translations for the language.
#
sub _load_language {
  my ($self,$language) = @_;

  # get the name of the language file, then open it
  my $file;
  if (exists $self->{loaded_languages}->{$language}) {
    $file = $self->{loaded_languages}->{$language}->{file};
  }
  unless (defined $file) {
    $file = $self->_get_language_filename($language);
    return unless (defined $file);
    $self->{loaded_languages}->{$language}->{file} = $file;
  }
  $self->{loaded_languages}->{$language}->{mtime} = (stat($file))[9];

  # Load the translations from the file (skip empty lines, or comments)
  my $rules = $self->{rules}->{$language};
  $rules = {} unless $rules;
  my ($key,$expression,$priority,$translation,$context);
  my $in_group = 0;
  my $line = 0;
  my $encoding = $self->{encoding};
  open (FH, "<:encoding($encoding)", "$file") || return;

  while (<FH>) {
    chomp;
    $line++;
    $_ = alltrim($_);
    next if (not defined or length == 0 or /^#/);

    # search for group entries
    /^
      ([^=]*)=(.*)
      |
      (?:.+)
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
    next unless (defined $translation);
    $expression = "" unless $expression;
    $priority = 0 unless $priority;
    $context = "" unless $context;

    # Make this linguistic rule, and add it to any others that may exist for this language/key
    $in_group--;
    my $entries;
    if ($context) {
      $entries = $rules->{$key}{$context};
      unless ($entries) {
        $entries = [] unless $entries;
        $rules->{$key}{$context} = $entries;
      }
    } else {
      $entries = $rules->{$key}{_};
      unless ($entries) {
        $entries = [] unless $entries;
        $rules->{$key}{_} = $entries;
      }
    }
    push @$entries, $self->make_rule(
      key => $key,
      language => $language,
      expression => $expression,
      priority => $priority,
      translation => $translation,
    );

    $key = $expression = $priority = $translation = $context = undef;
  }

  close FH;
  $self->{rules}->{$language} = $rules;
}

#--------------------------------------------------------------------------
#
# Helper routine for looking up filenames for a given language
#
sub _get_language_filename {
  my ($self, $language) = @_;
  my $path = $self->{directory} ."/". $language . $language_file_extension;
  if ((-f $path || -l $path) and -r $path) {
    print STDERR "Found new language file: $path" if $DEBUG > 2;
    return $path;
  }
  return undef;
}

1;
__END__
#--------------------------------------------------------------------------

=head1 TODO

Need to re-implement file parser to allow the syntax of the file to be a
little more flexible / user-friendly.

=head1 NOTES

If you find that the filename extension B<.mpt> is unsuitable, you can
change it by setting the variable:

C<$Locale::MakePhrase::BackingStore::Directory::language_file_extension>

to the extension that you prefer.

=cut


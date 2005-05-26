package Locale::MakePhrase;
our $VERSION = 0.2;
our $DEBUG = 0;

=head1 NAME

Locale::MakePhrase - Language translation facility

=head1 SYNOPSIS

These group of modules are used to translate application text strings,
which may or may not include values which also need to be translated,
into the prefered language of the end-user.

Example:

  use Locale::MakePhrase::BackingStore::Directory;
  use Locale::MakePhrase;
  my $bs = new Locale::MakePhrase::BackingStore::Directory(
    directory => '/some/path/to/language/files',
  );
  my $mp = new Locale::MakePhrase(
    language => 'en_AU',
    backing_store => $bs,
  );
  ...
  my $file_count = 1;
  print $mp->translate("Please select [_1] colors.",$file_count);

Output:

  Please select a colour.

Notice that a) the word 'color' has been localised to Australian
English, and b) that the argument has influenced the resultant output
text to take into account the display of the singular version.

=head1 DESCRIPTION

This aim of these modules are to implement run-time evaluation of an
input phrase, including program arguments, and have it generate a
suitable output phrase, in the language and encoding specified by the
user of the application.

Since this problem has been around for some time, there are a number
of sources of useful information available on the web, which describes
why this problem is hard to solve.  The problem with most existing
solutions is that each design suffers some form of limitation, often
due to the designer thinking that there are enough commonalities
between all/some langugaes that these commonalities can be factored
into a various rules which can be implemented in programming code.

However, each language has it own history and evolution. Thus it is
pointless to compare two different languages unless they have a common
history and a common character set.

I<Before> continuing to read this document, you really should read the
following info on the L<Locale::Maketext> Perl module:

  http://search.cpan.org/~sburke/Locale-Maketext-1.08/lib/Locale/Maketext.pod

and at the slides presented here:

  http://www.autrijus.org/webl10n/

The L<Locale::MakePhrase> modules are based on a design similar to the
L<Locale::Maketext> module, except that this new implementation has
taken a different approach, that being...

Since it is possible (and quite likely) that the application will need
to be able to understand the language rules of any specific language,
we want to use a run-time evaluation of the rules that a linguist
would use to convert one language to another.  Thus we have coined the
term I<linguistic rules> as a means to describe this technique.  These
rules are used to decide which piece of text is displayed, for a given
input text and arguments.

=head1 REQUIREMENTS

The L<Locale::MakePhrase> module was initially designed to meet the
requirements of a web application (as opposed to a desktop
application), which may display many languages in the HTML form at any
given instance.

Its design is modelled on a similar design of using language lexicons,
which is in use in the existing L<Locale::Maketext> Perl module.  The
reason for building a new module is because:

=over 2

=item -

We wanted to completely abstract the language rule capability, to be
programming language agnostic so that we could re-implement this
module in other programming languages.

=item -

We needed run-time evaluation of the rules, since the translations
may be updated at any time; new rules may be added whenever there is
some ambigutiy in the existing phrase.  Also, we didn't want to
re-start the application whenever we updated a rule.

=item -

We would like to support various types of storage mechanisms for the
translations.  The origonal design constraint prefered the use of a
PostgreSQL database to hold the translations - most existing language
translation systems use flat files.

=item -

We want to store/manipulate the current text phrase, only encoded in
UTF-8 (ie we dont want to store the text in a locale-specific
encoding).  This allows us to output text to any other character set.

=back

As an example of application usage, it is possible for a Hebrew
speaking user to be logged into a web-form which contains Japanese
data. As such they will see:

=over 3

=item a)

Menus and tooltips will be translated into the users' language (ie Hebrew).

=item b)

Titles will be in the language of the dataset (ie Japanese).

=item c)

Some of the data was in Latin character set (ie English).

=item d)

If the user prefered to see the page as RTL rather than LTR, the page
was altered to reflect this preference.

=back

=head1 BACKGROUND

When implementing any new software, it is necessary to understand
the problem domain.  In the case of language translation, there
are a number of requirements that we can define:

=over 3

=item a)

Quite a few people speak multiple languages; we would like the
language translation system to use the users preferred language
localisation, or if we don't know which language that is, try to make
an approximate guess, based on application capabilites.

=over 4

=item Eg:

In a web-browser, the user normally sets their prefered language/dialect.
The browser normally sends this information to a web-server during the
request for a page.  The server may choose to show the page contents in
the language the user prefers.

=back

=item b)

Since some people speak multiple languages, the application may not
have been localised to their prefered localisation.  We should try to
fallback to using a language which is similar.

=over 4

=item Eg:

If there are no Spanish translations available, we should fallback
to Mexican, since Mexican and Spanish have many words in common.

=back

=item c)

Some languages support the notion of a dialect for that language.  A
good example is that the English language is used in many
countries, but countries such as the United States, Australia and
Great Britain each have their own localised version ie. the dialect is
specified as the country or region.  The language translation
mechanism needs to be able to use the users' preferred dialect when
looking up the text to display.  If no translation is found, then it
should fall back to the parent language.

=over 4

=item Eg:

The language/dialect of Australia is defined as 'en_AU' - when we
lookup a text translation, if we fail we should try to lookup the 'en'
translation.

=back

=item d)

Some languages are written using a script which displays its
output as right-to-left text (as used by Arabic, Hebrew, etc), rather
than left-to-right text (as used by English, Latin, Greek, etc).  The
language translation mechanism should allow the text display mechanism
to change the text direction if that is a requirement (which is
another reason for mandating the use of UTF-8).

=item e)

The string to be translated should support the ability to re-order
the wording of the text.

=over 4

=item Eg:

In English we would normally say something like "Please enter your
name"; in Japanese the equivalent translation would be something like
"Enter your name, please" (although it would be in Japanese, not
English).

=back

=item f)

The text translation mechanism should support the ability to show
arguments supplied to the string (by the application), within the
correct context of the meaning of the string.

=over 4

=item Eg:

We could say something like "You selected 4 balls" (where the number 4
is program dependant); in another language you may want to say the
equivalent of "4 balls selected".

=back

Notice that the numeric position has moved from being the third
mnemonic, to being the first mnemonic.  The requirement is that we
would like to be able to rearrange the order/placement of any
mnemonic (including any program arguments).

=item g)

We would like to be able to support an arbitrary number of argument
replacements.  We shouldn't be limited in the number of replacements
that need to occur, for any given number program arguments.

=over 4

=item Eg:

We want to have an unlimited number of placeholders as exemplified
by the string "Select __ balls, __ bats, __ wickets, plus choose __
people, ___ ..." and so on.

=back

=item h)

Most program arguments that are given to strings are in numeric
format (i.e. they are a number).  We would also like to support
arguments which are text strings, which themselves should be open to
language translation (but only after rule evaluation).  The purpose
being that the output phrase should make sense within the current
context of the application.

=item i)

In a lot of languages there is the concept of singular and plural.
While in other languages there is no such concept, while in others
still there is the concept of duality.  There is also the concept that
a phrase can be descriptive when discussing the zero of something.
Thus we want to display a specific phrase, depending on the value of
an argument.

=over 4

=item Eg:

In English, the following text "Selected __ files" has multiple
possible outputs, depending on the program value; we can have:

 0 case: "No files selected" - no numeric value
 1 case: "One file selected" - 'files' is singular
 2 case: "Selected two files" - the '__' is a text value, not a number
 more than 2 case: "Lots of selections" - no direct comparison to the original text

=back

...as we can see, this is just for translating a single text
string, from English to English.

To counter this problem, the translation system needs to be able
to apply linguistic rules to the original text, so that it can
evaluate which piece of text should be displayed, given the current
context and program argument.

=item j)

When updating a specific phrase for language translation, the next
screen re-draw should show the new translation text. Thus translations
need to be dynamically changeable, and run-time configurable.

=back

=head1 INTERNAL TEXT ENCODING

This module uses UTF-8 text encoding internally, thus it requires a
minimum of Perl 5.8.  So, for any given application string and user
language combination, we require the backing store look-up the
combination, then return a list of L<Locale::MakePhrase::LanguageRule>
objects, which must be created with the key and translated strings
being stored in the UTF-8 encoding.

Thus, to simplify the string-load functionality, we recommend to load
/ store the translated strings as UTF-8 encoded strings.  See
L<Locale::MakePhrase::BackingStore> for more information.

=over 4

=item ie.

The PostgreSQL backing store assumes that the database instance
stores strings in the UNICODE encoding (rather than, say, ASCII); this
avoids the need to translate every string when we load it.

=back

=head1 OUTPUT TEXT ENCODING

L<Locale::MakePhrase> uses UTF-8 encooding internally, as described
above. This is also the default output encoding.  You can choose to
have a different output encoding, such as ISO-8859-1.

Normlly, if the output display mechanism can display UNICODE (encoded as
UTF-8), then text will be rendered in the correct language and correct
text direction (ie. left-to-right or right-to-left).

By supplying the encoding as a constructor argument, L<Locale::MakePhrase>
will transpose the translated text from UTF-8, into your output-specific
encoding (using the L<Encode> modeule).  This is useful in cases where
font support within an application, hasn't yet evolved to the same
level as a language-specific font.

See the L<Encode> module for a list of available output encodings.

Default output character set encoding: B<UTF-8>

=head1 WHAT ARE LINGUISTIC RULES?

Since the concept of a linguistic rule is at the heart of this
translation module, its documentation is located in L<Locale::MakePhrase::RuleManager>.
It explains the syntax of the rule expressions, how rules are sorted and
selected, as well as the operators and functions that are available
within the expressions.  You should read that information, before
continuing.

=over 2

=item Available operators:

B<==>, B<!=>, B<E<lt>>, B<E<gt>>, B<E<lt>=>, B<E<gt>=>, B<eq>, B<ne>

=item Available functions:

B<defined(x)>, B<length(x)>, B<int(x)>, B<abs(n)>, B<lc(s)>, B<uc(s)>,
B<left(s,n)>, B<right(s,n)>, B<substr(s,n)>, B<substr(s,n,r)>

=back

=head1 API

The following functions part of the core L<Locale::MakePhrase> API:

=cut

{ no warnings; require v5.8.0; }
use strict;
use warnings;
use utf8;
use integer;
use base qw();
use Data::Dumper;
use I18N::LangTags 0.21 ();
use Encode;
use Encode::Alias;
use Locale::MakePhrase::BackingStore;
use Locale::MakePhrase::RuleManager;
use Locale::MakePhrase::LanguageRule;
use Locale::MakePhrase::Utils qw(is_number die_from_caller);
use constant MALFORMED_MODE_ESCAPE => Encode::FB_PERLQQ;
use constant MALFORMED_MODE_HTML => Encode::FB_HTMLCREF;
use constant MALFORMED_MODE_XML => Encode::FB_XMLCREF;
use constant NUMERIC_FORMAT_NONE => 1;
use constant NUMERIC_FORMAT_COMMA => 2;
use constant NUMERIC_FORMAT_DOT => 3;
our $default_language = "en";
our $default_backing_store = "Locale::MakePhrase::BackingStore";
our $default_rule_manager = "Locale::MakePhrase::RuleManager";
our $default_malformed_mode = MALFORMED_MODE_ESCAPE;
our $default_numeric_format = NUMERIC_FORMAT_COMMA;
our $default_panic_language_lookup = 0;
our $internal_encoding = "utf-8";
$Data::Dumper::Indent = 1 if $DEBUG;

# Exported symbols
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(MALFORMED_MODE_ESCAPE MALFORMED_MODE_HTML MALFORMED_MODE_XML NUMERIC_FORMAT_NONE NUMERIC_FORMAT_COMMA NUMERIC_FORMAT_DOT);

# We add the 'utf-8' alias for the 'utf8' encoding,
# as we support both syntactical forms.
Encode::Alias::define_alias('utf-8' => 'utf8');

#--------------------------------------------------------------------------

=head2 new()

Construct new instance of Locale::MakePhrase object.  Takes the
following named parameters (ie via a hash or hashref):

=over 2

=item C<language>

=item C<languages>

Specify one or more languages which are used for locating the
correct language string (all forms are supported; first found is used).

They take either a string (eg 'en'), a comma-seperated list (eg
'en_AU, en_GB') or an array of strings (eg ['en_AU','en_GB']).

The order specified, is the order that phrases are looked up.  These
strings go through a manipulation process (using the Perl module
L<I18N::LangTags>) of:

=over 3

=item 1)

The strings are converted to RFC3066 language tags; these become
the primary tags.

=item 2)

Superordinate tags are retrieved for each primary tag.

=item 3)

Alternates of the primary tags are then retrieved.

=item 4)

Panic language tags are retrieved for each primary tag (if enabled).

=item 5)

The fallback language is retrieved (see 'fallback language').

=item 6)

Duplicate language tags are removed.

=item 7)

All tags are converted to lowercase, and '-' are changed to '_'.

=back

This leaves us with a list of at least the fallback language.

=item C<charset>

=item C<encoding>

This option (both forms are supported; first found is used) allows you
to change the output character set encoding, to something other than
UTF-8, such as ISO-8859-1.

See L<ENCODING|Locale::MakePhrase/ENCODING> for more information.

=item C<backing_store>

Takes either a reference to a backing store instance, or to a string
which can be used to dynamically construct the instance.

The final backing store instance must have a type of L<Locale::MakePhrase::BackingStore>.

Defaults to: L<Locale::MakePhrase::BackingStore>

=item C<rule_manager>

Takes either a reference to a rule manager instance, or to a string
which can be used to dynamically construct the instance.

The final manager instance must have a type of L<Locale::MakePhrase::RuleManager>.

Defaults to: L<Locale::MakePhrase::RuleManager>

=item C<malformed_character_mode>

Perl normally outputs \x{HH} for malformed characters (or \x{HHHH},
\x{HHHHHH}, etc. for wide characters).  Setting this value, changes
the behaviour to output alternative character entity formats.

Note that if you are using L<Locale::MakePhrase> to generate strings
used within web pages / HTML, you should set this parameter to
C<MALFORMED_MODE_HTML>.

=item C<numeric_format>

This option allows the user to control how numbers are output.  You can
set the output to be one of three forms.  Numeric stringification can
be set to output using one of the following formats:

=over 2

=item C<NUMERIC_FORMAT_NONE>

Dont do any pretty-printing of the number

=item C<NUMERIC_FORMAT_COMMA>

Place comma seperators before every third digit, as in: 10,000,000.0

=item C<NUMERIC_FORMAT_DOT>

Place dot (full-stop) seperators before every third digit, as in: 10.000.000.000,0

=back

Defaults to: B<NUMERIC_FORMAT_COMMA>

=item C<die_on_bad_args>

Set this option to true to make L<Locale::MakePhrase> die if there is
an error in your usage of this module.

Default: dont die; gracefully handle mis-use by replacing missing
argument with an empty string.

=item C<show_bad_args>

Set this option to true to make L<Locale::MakePhrase> show the which
application string arguments, are not defined.  It does this by using
the phrase B<E<lt>UNDEFINEDE<gt>>, in place of the undefined value.

Default: dont show undefined arguments; gracefully replaces arguments
with an empty string

=item C<panic_language_lookup>

Set this option to true to make L<Locale::MakePhrase> load 'panic'
languages as defined by L<I18N::LangTags/panic_languages>.  Basically
it provides a mechanism to allow the engine to return a language
string from languages which has a similar heritage to the primary
language(s), if a translation from the primary language hasn't been
found.

eg: Spanish has a similar heritage as Italian, thus if no translations
are found in Itelian, then Spanish translations will be used.

Default: donet lookup panic-languages

=item Notes:

If the arguments aren't a hash or hashref, then we assume that the
arguments are languages tags.

If you dont supply any language, the fallback language will be used.
Default language: B<en>.

=back

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = bless {}, $class;

  # We allow different forms of argument passing.
  # The only argument we really need is the language, but we can allow other arguments as well.
  my %options;
  if (@_ == 1 and ref($_[0]) eq "HASH") {
    %options = %{$_[0]};
  } elsif (@_ > 1 and not(@_ % 2)) {
    %options = @_;
  } elsif (@_ > 0) {
    my @languages = split(',',$_[0]);
    $options{languages} = \@languages;
  };
  print STDERR "Arguments to ". $class .": ". Dumper(\%options) if $DEBUG > 5;
  $self->{options} = \%options;

  # allow sub-class to control construction
  $self = $self->init();
  return undef unless $self;

  # process options, and initialise module
  $self->{backing_store} = $self->_attach_backing_store();
  $self->{rule_manager} = $self->_get_rule_manager();
  $self->{languages} = $self->_get_languages();
  $self->{encoding} = $self->_get_encoding();
  $self->{malformed_character_mode} = $self->_get_malformed_mode();
  $self->{numeric_format} = $self->_get_numeric_format();
  $self->{die_on_bad_args} = $options{die_on_bad_args} ? 1 : 0;
  $self->{show_bad_args} = $options{show_bad_args} ? 1 : 0;
  $self->{language_modules} = $self->_load_language_modules();
  $self->{panic_language_lookup} = $self->_get_panic_language_lookup();

  print STDERR "Resultant $class object: ". Dumper($self) if $DEBUG > 7;
  return $self;
}

#--------------------------------------------------------------------------

=head2 $self init([...])

Allow sub-class a chance to control construction of the object.  You
must return a reference to $self, to 'allow' the construction to
complete.

At this point of construction you can call C<$self-E<gt>options()>
which returns a reference to the current constructor options.  This
allows you to add/modify any existing options; for example you may
want to inject something specific...

=cut

sub init { shift }

#--------------------------------------------------------------------------

=head2 $string translate($string [, ...])

This is a primary entry point; call this with your string and any
program arguments which need to be translated.

This function is a wrapper around the L</context_translate> function,
where the context is set to undef.

=cut

sub translate {
  die_from_caller("translate() requires at least one parameter") unless @_ > 1;
  return shift->context_translate(undef,@_);
}

#--------------------------------------------------------------------------

=head2 $string context_translate($context, $string [, ...])

[$context is either a text string or an object reference (which then
gets qualified into its class name).]

This is a primary entry point; call this with your application context,
your string and any program arguments which need to be translated.

In most cases the context is undef (as a result of being called via
the L<translate> function).  However, in some cases you will find that
you will use the same text phrase in one part of your application, as
another part of your application, but the meaning of the phrase is
different, due to the different application context; supplying a
context will allow your backing store to use the extra context
information, to return the correct language rules.

The steps involved in a string translation are:

=over 3

=item 1)

Fetch all possible translation rules for all language tags (including
alternates and the fallbacks), from the backing store.  The store will
return a list reference of LanguageRule objects.

=item 2)

Sort the list based on the implementation defined in the
L<Locale::MakePhrase::RuleManager> module.

=item 3)

The the rule instance for which the rule-expression evaluates to B<true>
for the supplied program arguments (if there is no expression, the rule
is always true).

=item 4)

If no rules have been selected, then make a rule from the input string.

=item 5)

Apply the program arguments to the rules' translated text.  If the
argument is a text phrase, it undergoes the language translation
procedure.  If the argument is numeric, it is formated by the
C<format_numeric> method.

=item 6)

We apply the output character set encoding to convert the text from
UTF-8 into the prefered character set.  (This does nothing if the
output encoding is UTF-8.)

=back

=cut

sub context_translate {
  die_from_caller("context_translate() requires at least two parameters") unless @_ > 2;
  my ($self,$context,$key) = (shift,shift,shift);
  die_from_caller("context_translate() requires a valid key") unless (defined $key and length $key);
  $context = ref($context) if (defined $context and ref($context) ne 'SCALAR');
  print STDERR "Translation key: $key\n" if $DEBUG;

  my $backing_store = $self->{backing_store};
  my $languages = $self->{languages};

  # Get all possible translations/rules from backing store
  my $rule_objs = $backing_store->get_rules($context,$key,$languages);

  # Sort the rules according to the linguistic rule algorithms
  $rule_objs = $self->_sort_rules($rule_objs,$languages);

  # Select the specific rule, based on the linguistic rules for each rule
  my $rule_obj = $self->_select_rule($rule_objs, @_);

  # at this point we can clean up some resources
  $backing_store = undef;
  $languages = undef;
  $rule_objs = undef;

  # If no rule found, use input key
  $rule_obj = new Locale::MakePhrase::LanguageRule(
    language => $self->fallback_language,
    translation => $key,
  ) unless (defined $rule_obj);

  # Apply arguments to translated text
  my $translated_text = $self->_apply_arguments($rule_obj, @_);

  # apply encoding
  $translated_text = $self->_apply_encoding($translated_text);

  print STDERR "Translated text: $translated_text\n" if $DEBUG;
  return $translated_text;
}

#--------------------------------------------------------------------------

=head2 $string format_number($number)

This method implements the numbers-specific formatting.  The default
implementation will stringify the number (which usually means that we
put a comma seperator) by delegating the call to the C<stringify_number>
method.

To provide custom handling of number formatting, you can do one of:

=over 3

=item a)

Implement 'per-language' number formatting, by sub-classing the
L<Locale::MakePhrase::Language> module, then implementing a
C<format_number> method.

=item b)

Sub-class L<Locale::MakePhrase>, then overload the C<format_number>
method.

=item c)

Set the available L<Locale::MakePhrase> number formatting options;
these options affect the C<stringify_number> method.

=back

=cut

sub format_number {
  my ($self, $num) = @_;

  # Allow the custom language-handling module a chance at formatting the number
  if (ref($self)) {
    my $modules = $self->{language_modules};
    my $can;
    foreach my $module (@$modules) {
      $can = $module->can('format_number');
      if ($can) {
        print STDERR "Found language specific number formatter on module: ". ref($module) ."\n" if $DEBUG > 1;
        return &$can($module,$num);
      }
    }
  }

  return $self->stringify_number($num);
}

#--------------------------------------------------------------------------

=head2 $string stringify_number($number)

This method implements the stringification of number to a suitable
output format (as defined by the C<numeric_format> constructor
argument).

When sub-classing L<Locale::MakePhrase>, by overloading this method
you can implement custom numeric stringification.

=cut

sub stringify_number {
  no integer;
  my ($self,$num) = @_;

  # Don't let the %G of sprintf, turn ten million (or bigger) into 1E+007
  if($num < 10_000_000_000 and $num > -10_000_000_000 and $num == int($num)) {
    $num += 0;  # Just use normal integer stringification.
  } else {
    $num = CORE::sprintf("%G", $num);
  }

  # We optionally apply numeric formatting (ie put comma's into big numbers)
  if (ref($self) and $self->{numeric_format} != NUMERIC_FORMAT_NONE) {

    # The initial \d+ gobbles as many digits as it can, and then we
    # backtrack so it un-eats the rightmost three, and then we
    # insert the comma there.
    while( $num =~ s/^([-+]?\d+)(\d{3})/$1,$2/s ) {1}

    # Convert comma's into dots (and vice versa)
    $num =~ tr<.,><,.> if ($self->{numeric_format} == NUMERIC_FORMAT_DOT);
  }

  return $num;
}

#--------------------------------------------------------------------------

=head2 $backing_store fallback_backing_store()

Backing store to use, if not specified on construction.  You can
overload this in a sub-class.

=cut

sub fallback_backing_store { $default_backing_store }

#--------------------------------------------------------------------------

=head2 $string fallback_language()

Language to fallback to, if all others fail (this defaults to 'B<en>').
You can override this method in a sub-class.

Usually this will be the language that you are writing your application
code (eg you may be coding using German rather than English).

Note that this must return a RFC-3066 compliant language tag.

=cut

sub fallback_language { $default_language }

#--------------------------------------------------------------------------

=head2 $string_array language_classes()

This method returns a list of possible class names (which must be
sub-classes of L<Locale::MakePhrase::Language>) which can get
prepended to the language tags for this instance.  L<Locale::MakePhrase>
will then try to dynamically load these modules during construction.

The idea being that you simply need to put your language-specific
module in the same directory as your sub-class, thus we will find the
custom modules.

Alternatively, you can sub-class this method, to return the correct
class heirachy name.

=cut

sub language_classes {
  my ($self) = @_;
  my $class = ref($self);
  my $superclass = $class;
  $superclass =~ s/(.*)::.+$/$1/;
  my @classes = (
    $class,
    $class."::Language",
    $class."::Languages",
    $superclass,
    $superclass."::Language",
    $superclass."::Languages"
  );
  return \@classes;
}

#--------------------------------------------------------------------------

=head2 $format numeric_format(<$format>)

This method allows you to set and/or get the format that is being used
for numeric formatting.

=cut

sub numeric_format             {
  if (@_ > 1) {
    if ($_[1] == NUMERIC_FORMAT_NONE or
        $_[1] == NUMERIC_FORMAT_COMMA or
        $_[1] == NUMERIC_FORMAT_DOT) {
      $_[0]->{numeric_format} = $_[1];
    } else {
      die_from_caller("Invalid numeric format: " . $_[1]);
    }
  }
  shift->{numeric_format};
}
#--------------------------------------------------------------------------

=head2 Accessor methods

=over 2

=item $hash B<options()>

Returns the options that were supplied to the constructor.

=item $string_array B<languages()>

Returns a list of the language tags that are in use.

=item $object_list B<language_modules()>

Returns a list of the loaded language modules.

=item $object B<backing_store()>

Returns the loaded backing store instance.

=item $object B<rule_manager()>

Returns the loaded rule manager instance.

=item $string B<encoding()>

Returns the output character set encoding.

=item $int B<malformed_character_mode()>

Returns the current UTF-8 malformed character output mode.

=item $bool B<die_on_bad_args()>

Returns the current state of 'L<die_on_bad_args|Locale::MakePhrase/die_on_bad_args>'.

=item $bool B<show_bad_args()>

Returns the current state of 'L<show_bad_args|Locale::MakePhrase/show_bad_args>'.

=item $bool b<panic_language_lookup()>

Returns the current state of 'L<panic_language_lookup|Locale::MakePhrase/panic_language_lookup>'.

=back

=cut

sub options                    { shift->{options}                    }
sub languages                  { shift->{languages}                  }
sub language_modules           { shift->{language_modules}           }
sub backing_store              { shift->{backing_store}              }
sub rule_manager               { shift->{rule_manager}               }
sub encoding                   { shift->{encoding}                   }
sub malformed_character_mode   { shift->{malformed_character_mode}   }
sub die_on_bad_args            { shift->{die_on_bad_args}            }
sub show_bad_args              { shift->{show_bad_args}              }
sub panic_language_lookup      { shift->{panic_language_lookup}      }

#--------------------------------------------------------------------------
# The following methods are not part of the API - they are private.
#
# This means that everything above this code-break is allowed/designed
# to be overloaded.
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
#
# Load/construct the backing store.
#
# We can pass in a string name of a backing store to use,
# or an object reference to a previously constructed backing store.
#
sub _attach_backing_store {
  my ($self) = @_;
  my $options = $self->{options};
  my $backing_store = $options->{backing_store};
  my $store;

  # use default backing store if none defined
  unless ($backing_store) {
    $backing_store = $self->fallback_backing_store;
    die_from_caller("Failed to locate a default backing store") unless $backing_store;
    print STDERR "Using fallback backing store ($backing_store)\n" if $DEBUG > 1;
  }

  # if not a reference, try to construct one
  unless (ref($backing_store)) {

    ## see if perl module can be loaded
    eval "use $backing_store";
    die_from_caller("Failed to load backing store: $backing_store") if ($@);

    ## try constructing it
    eval '$store = '. "$backing_store" .'->new()';
    die_from_caller("Failed to construct backing store: $backing_store") if ($@);
    die_from_caller("Backing store connection failure: $backing_store") unless ($store);

  # use a passed in reference to a backing store
  } else {
    $store = $backing_store;
  }
  $options->{backing_store} = ref($store);

  ## make sure backing store ISA Locale::MakePhrase::BackingStore object
  die_from_caller("Backing store is not of type Local::MakePhrase::BackingStore")
    unless ($store->isa('Locale::MakePhrase::BackingStore'));

  return $store;
}

#--------------------------------------------------------------------------
#
# Return an rule_manager object that is to be used in subsequent rule evaluations
#
# We can pass in a string name of a rule manager to use,
# or an object reference to a previously constructed rule manager.
#
sub _get_rule_manager {
  my ($self) = @_;
  my $options = $self->{options};
  my $rule_manager = $options->{rule_manager};
  my $manager;

  # use default manager if none defined
  unless ($rule_manager) {
    print STDERR "Using default rule_manager ($default_rule_manager)\n" if $DEBUG > 1;
    $rule_manager = $default_rule_manager;
  }

  # if its not a reference, try constructing it
  unless (ref($rule_manager)) {

    # see if perl modle can be loaded
    eval "use $rule_manager";
    die_from_caller("Failed to load rule manager: $rule_manager") if ($@);

    # try constructing it
    eval '$manager = '. "$rule_manager" .'->new()';
    die_from_caller("Failed to construct rule manager: $rule_manager") if ($@ or not $manager);

  # use passed in rule_manager
  } else {
    $manager = $rule_manager;
  }
  $options->{rule_manager} = ref($manager);

  # make sure rule_manager ISA Locale::MakePhrase::RuleManager object
  die_from_caller("Rule manager is not of type Locale::MakePhrase::RuleManager")
    unless ($manager->isa('Locale::MakePhrase::RuleManager'));

  return $manager;
}

#--------------------------------------------------------------------------
#
# Return list of languages that we want to handle (highest to lowest priority).
#
# This implementation does the following:
#
# a) grab the required language(s) by looking for optins (in order) of:
#    - language -> string,
#    - languages -> string array,
#    - languages -> string containing a comma seperated list,
#
# b) then convert those language/dialect(s) into 'languages tags'
#
# c) generate 'super ordinate' language tags for results from b)
#
# d) generate 'alternate' languages tags for result from c)
#
# e) add the 'panic' language tags from the results of d) (if enabled)
#
# f) add the fallback language (after converting it to a language tag)
#
# g) strip off any duplicate tags
#
# h) make sure all tags only contain [a-z0-9_], by
#    - stripping unknown characters
#    - converting uppercase to lowercase
#    - converting '-' to '_'
#
sub _get_languages {
  my ($self) = @_;
  my $options = $self->{options};
  my @languages;

  ## get prefered language(s)
  if (exists $options->{language}) {
    push @languages, $options->{language};
  } elsif (exists $options->{languages} && ref($options->{languages}) eq "ARRAY") {
    @languages = @{$options->{languages}};
  } elsif (exists $options->{languages}) {
    @languages = split(',',$options->{languages});
  } 

  # Lookup real language/dialect definitions, from supplied language
  @languages = map I18N::LangTags::locale2language_tag($_), @languages;
  push @languages, map I18N::LangTags::super_languages($_), @languages;

  # catch alternations
  @languages =  map { $_, I18N::LangTags::alternate_language_tags($_) } @languages;

  # get at least an approximate language
  if ($options->{panic_language_lookup}) {
    push @languages, I18N::LangTags::panic_languages(@languages);
  }

  # add a fallback language, just in case specified languages dont work
  my $fallback = $self->fallback_language;
  die_from_caller("Must implement something valid for 'fallback_language' method") unless $fallback;
  $fallback = I18N::LangTags::locale2language_tag($fallback);
  push @languages, $fallback;

  # strip off duplicate languages
  {
    my @langs;
    LOOP: foreach my $lang (@languages) {
      foreach my $l (@langs) { next LOOP if I18N::LangTags::same_language_tag($l,$lang); }
      push @langs, $lang;
    }
    @languages = @langs;
  }

  # final bit of processing:
  {
    my @langs;
    foreach my $lang (@languages) {
      $lang =~ tr<-A-Z><_a-z>;   # lc, and turn - to _
      $lang =~ tr<_a-z0-9><>cd;  # remove all but a-z0-9_
      next unless $lang;
      push @langs, $lang;
    }
    @languages = @langs;
  }

  print STDERR "Available languages: ", join(',',@languages), "\n" if $DEBUG > 1;
  return \@languages;
}

#--------------------------------------------------------------------------
#
# If the user specified a charset (and its not UTF-8), we want to be
# able to encode the # output translation into that charset, before
# returning.  Here we simply capture that info.
#
sub _get_encoding {
  my ($self) = @_;
  my $options = $self->{options};
  my $encoding = $internal_encoding;
  if ($options->{charset}) {
    $encoding = $options->{charset};
  } elsif ($options->{encoding}) {
    $encoding = $options->{encoding};
  }
  $encoding =~ tr<_A-Z><-a-z>; # lc, and turn _ to -
  return $encoding;
}

#--------------------------------------------------------------------------
#
# Figure out what encoding mode we want.
#
sub _get_malformed_mode {
  my ($self) = @_;
  my $options = $self->{options};
  my $mode = $default_malformed_mode;
  if ($options->{malformed_character_mode}) {
    if ($options->{malformed_character_mode} == MALFORMED_MODE_ESCAPE) {
      $mode = MALFORMED_MODE_ESCAPE;
    } elsif ($options->{malformed_character_mode} == MALFORMED_MODE_HTML) {
      $mode = MALFORMED_MODE_HTML;
    } elsif ($options->{malformed_character_mode} == MALFORMED_MODE_XML) {
      $mode = MALFORMED_MODE_XML;
    } else {
      die_from_caller("Unknown malformed-character mode: " . $options->{malformed_character_mode});
    }
  }
  return $mode;
}

#--------------------------------------------------------------------------
#
# Figure out what nmeric formatting we want
#
sub _get_numeric_format {
  my ($self) = @_;
  my $options = $self->{options};
  my $mode = $default_numeric_format;
  if ($options->{numeric_format}) {
    if ($options->{numeric_format} == NUMERIC_FORMAT_NONE) {
      $mode = NUMERIC_FORMAT_NONE;
    } elsif ($options->{numeric_format} == NUMERIC_FORMAT_DOT) {
      $mode = NUMERIC_FORMAT_DOT;
    } elsif ($options->{numeric_format} == NUMERIC_FORMAT_COMMA) {
      $mode = NUMERIC_FORMAT_COMMA;
    } else {
      die_from_caller("Unknown numeric-formatting mode: " . $options->{numeric_format});
    }
  }
  return $mode;
}

#--------------------------------------------------------------------------
#
# We try to load all the languages that user is able to use.
# This allows the application to install their own method calls into the
# language (even at run-time), if they really deem it to be necessary.
#
sub _load_language_modules {
  my ($self) = @_;
  my $languages = $self->{languages};
  my $classes = $self->language_classes();

  my @language_modules;
  foreach my $language (@$languages) {

    # try loading the language specific module
    # (we try various module-names to see which one resolves)
    my $module;
    foreach my $class (@$classes) {
      $module = $class ."::". $language;
      print STDERR "Trying to load language module: $module\n" if $DEBUG > 2;
      eval "use ". $module;
      last unless ($@);
      $module = undef;
    }
    next unless $module;
    print STDERR "Loaded language module: $module\n" if $DEBUG > 2;

    # try constructing the language specific module
    my $object;
    eval '$object = '. "$module" .'->new()';
    next if ($@);

    # coool - special code for this language
    print STDERR "Found custom language handling object for language: $language\n" if $DEBUG > 1;
    push @language_modules, $object;
  }

  return \@language_modules;
}

#--------------------------------------------------------------------------
#
# If the user wants to enable 'panic language' support, allow it...
#
sub _get_panic_language_lookup {
  my ($self) = @_;
  my $options = $self->{options};
  my $mode = $default_panic_language_lookup;
  if ($options->{panic_language_lookup}) {
    if ($options->{panic_language_lookup} == 0 or $options->{panic_language_lookup} == 1) {
      $mode = $options->{panic_language_lookup};
    } else {
      die_from_caller("Unknown value for lookup of panic-languages: " . $options->{panic_language_lookup});
    }
  }
  return $mode;
}

#--------------------------------------------------------------------------
#
# Take the list of all rules, then sort them by language, then by priority,
# then by non-specified rule/language
#
sub _sort_rules {
  my ($self,$rule_objs,$languages) = @_;
  return undef if (not defined $rule_objs or @{$rule_objs} < 1);
  return $rule_objs if (@{$rule_objs} == 1);

  # sort the rules by language
  my $manager = $self->{rule_manager};
  return $manager->sort($rule_objs,$languages);
}

#--------------------------------------------------------------------------
#
# Select one of the rules, by applying the arguements
#
sub _select_rule {
  my ($self,$rule_objs,@args) = @_;
  return undef unless $rule_objs;
  my $manager = $self->{rule_manager};

  # run manager on the translation rules
  foreach my $r_obj (@$rule_objs) {
    my $expression = $r_obj->expression;
    return $r_obj if (length $expression == 0 or $manager->evaluate($expression,@args));
  }

  # no rule matched
  return undef;
}

#--------------------------------------------------------------------------
#
# Apply the arguments, to the new translated text
#
sub _apply_arguments {
  my ($self,$rule_obj) = (shift,shift);
  my $translation = $rule_obj->translation();
  my $manager = $self->{rule_manager};
  return $manager->apply_arguments($self,$translation,@_);
}

#--------------------------------------------------------------------------
#
# Apply the current encoding to the translated text
#
sub _apply_encoding {
  my ($self,$text) = @_;
  return $text if ($self->{encoding} eq $internal_encoding);
  my $encoded = Encode::decode($self->{encoding}, $text, $self->{malformed_character_mode});
  return $encoded;
}

#--------------------------------------------------------------------------
#
# We want to see if the function called, appears in the language specific sub-class.
# If so, then we execute that function, in _that class_'s scope, then return the results.
#
# We want to do this so as to allow functionality such as:
#    $mp->y_or_n( get_user_input() );
#
# If that doesn't work, try calling ourself as we may have been subclassed, or
# the method had be bound at run-time.
#
sub AUTOLOAD {
  my $self = shift;
  my $func = our $AUTOLOAD;
  $func =~ s/^.*:://;
  my $language_modules = $self->{language_modules};
  my $can;

  # See if the language-specific module contains this function name, and if so, run it
  foreach my $module (@$language_modules) {
    print STDERR "Trying to find function \"$func\" on module: ". ref($module) ."\n" if $DEBUG > 1;
    $can = $module->can($func);
    return &$can($module,@_) if ($can);
  }

  # try ourself...
  $can = $self->can($func);
  return &$can($self,@_) if ($can);

  # generate error from caller perspective, if we couldn't execute the function
  my $languages = $self->{languages};
  die_from_caller("No function \"$func\" found for languages:", join(',',@$languages), "\nor for myself:", ref($self));
}

#--------------------------------------------------------------------------
#
# Whenever use AUTOLOAD, we need to implement DESTROY
#
sub DESTROY {}

1;
__END__
#--------------------------------------------------------------------------

=head1 SUB-CLASSING

These modules can be used standalone, or they can be sub-classed so as
to control certain aspects of its behaviour.  Each inidividual module
from this group, is capable of being sub-classed; refer to each
modules' specific documentation, for more details.

In particular the L<Locale::MakePhrase::Language> module is designed
to be sub-classed, so as to support, say, language-specific keyboard
input handling.

=head2 Construction control

Due to the magic of inheritance, there are two primary ways to
control construction any of these modules:

=over 3

=item a)

Overload the C<new()> method

=over 2

=item -

Implement the C<new()> method in your sub-class

=item -

call C<SUPER::new()> so as to execute the parent class constructor

=item -

re-bless the returned object

=back

For example:

  sub new {
    my $class = shift;
    ...
    my $self = $class->SUPER::new(...sub-class specific arguments...);
    $self = bless $self, $class;
    ...
    return $self;
  }

=item b)

Overload the C<init()> method.

=over 2

=item -

implement the C<init()> method in your sub-class

=item -

return a reference to the current object.

=back

For example:

  sub init {
    my $self = shift;
    ...
    return $self;
  }

=back

=head2 Sub-classing this module

This module (C<Makephrase.pm>) has a number of methods which can be
overloaded:

=over 2

=item -

init()

=item -

fallback_backing_store()

=item -

fallback_language()

=item -

language_classes()

=item -

format_number()

=item -

stringify_number()

=back

=head1 DEBUGGING

Since this module and framework are relativley new, it is quite likely
that a few bugs may still exist.  By setting the module-specific
C<DEBUG> variable, you can enable debug messages to be sent to STDERR.

Set the value to zero, to disable debug.  Setting progressively higher
values (up to a maximum value of 9), results in more debug messages
being generated.

The following variables can be set:

  $Locale::MakePhrase::DEBUG
  $Locale::MakePhrase::RuleManager::DEBUG
  $Locale::MakePhrase::LanguageRule::DEBUG
  $Locale::MakePhrase::BackingStore::Cached::DEBUG
  $Locale::MakePhrase::BackingStore::File::DEBUG
  $Locale::MakePhrase::BackingStore::Directory::DEBUG
  $Locale::MakePhrase::BackingStore::PostgreSQL::DEBUG

=head1 NOTES

=head2 Text directionality

This module internally uses UTF-8 character encoding for text storage
for a number of reasons, one of them being for the ability to encode
the directionality within the text string using Unicode character
glyphs.

However it is up to the application drawing mechanism to support the
correct interpretation of these Unicode glyphs, before the text can be
displayed in the correct direction.

=head2 Localised text layout

In some languages there may be a requirement that we layout the
application interface, using a different layout scheme than what would
normally be available.  This requirement is known as layout
localisation.  An example might be, Chinese text should prefer to
layout top-to-bottom then left-to-right, (rather than left-to-right
then top-to-bottom).

This module doesn't provide this facility, as that is up to the
application layout mechanism to take into differences in layout.  eg:
A web-browser uses HTML as a formatting language; web-browsers do not
implement top-to-bottom text layout.

=head1 SEE ALSO

L<Locale::MakePhrase> is made up of a number of modules, for which
there is POD documentation for each module. Refer to:

=over 2

=item .  L<Locale::MakePhrase::Language>

=item .  L<Locale::MakePhrase::Language::en>

=item .  L<Locale::MakePhrase::LanguageRule>

=item .  L<Locale::MakePhrase::RuleManager>

=item .  L<Locale::MakePhrase::BackingStore>

=item .  L<Locale::MakePhrase::BackingStore::File>

=item .  L<Locale::MakePhrase::BackingStore::Directory>

=item .  L<Locale::MakePhrase::BackingStore::PostgreSQL>

=item .  L<Locale::MakePhrase::Utils>

=back

It also uses the following modules internally:

=over 2

=item .  L<Encode>

=item .  L<Encode::Alias>

=item .  L<I18N::LangTags>

=back

You can (and should) read the documentation provided by the
L<Locale::Maketext> module.

=head1 BUGS

=head2 Multiple levels of quoting

The rule expression parser cannot handle multiple levels of quoting.
It needs modification to support this.

=head2 Expression parsing failure

The rule expression parser splits the rule into sub-expressions by
chunking on ' && '.  This means it will fail to parse a text
evaluation containing these characters. For example this will fail to
parse:

  _1 eq ' && '

Since the ' && ' is not a common text expression, this bug will
probably never be fixed.

=head1 TODO

Need to add support for male / female context of phrase.  This could
be implemented using a context specific translation, however the
better way would be to add native support for gender.

=head1 CREDITES

This module was written for RedSheriff Limited; they paid for my time
to develop this module.

Various suggestions and bug fixes were also provided by:

=over 2

=over 2

=item Brendon Oliver

=item John Griffin

=back

=back

=head1 LICENSE

This module was written by Mathew Robertson L<mailto:mathew@users.sf.net>
for RedSheriff Limited L<http://www.redsheriff.com>.  Copyright (C) 2004

This module is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License version 2 (or
at your option, any later version) as published by the Free Software
Foundation L<http://www.fsf.org>.

This module is distributed WITHOUT ANY WARRANTY WHATSOEVER, in the
hope that it will be useful to others.

=cut


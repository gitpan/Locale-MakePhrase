#!/usr/local/bin/perl

use strict;
use warnings;
use Test;
BEGIN { plan tests => 7 };

use Locale::MakePhrase;
use Locale::MakePhrase::BackingStore::File;
ok(1);

$Locale::MakePhrase::DEBUG = 0;
$Locale::MakePhrase::Utils::DEBUG = 0;
$Locale::MakePhrase::LanguageRule::DEBUG = 0;
$Locale::MakePhrase::RuleManager::DEBUG = 0;
$Locale::MakePhrase::BackingStore::DEBUG = 0;
$Locale::MakePhrase::BackingStore::File::DEBUG = 0;


my $bs = new Locale::MakePhrase::BackingStore::File(
  file => 't/lang/lang.mpt',
);
ok($bs) or print "Bail out! Failed to locate translation file.\n";


my $mp = new Locale::MakePhrase(
  language => 'en_au',
  backing_store => $bs,
);
ok($mp) or print "Bail out! Failed to make a 'Locale::MakePhrase' instance.\n";

my $result;


# ---- Check numeric formatting ----

$result = $mp->translate("ID of selection: [_1]",1000);
ok($result eq "ID of selection: 1,000") or print "Bail out! Failed default numeric formatting.\n";

$mp->numeric_format(Locale::MakePhrase::NUMERIC_FORMAT_DOT);
$result = $mp->translate("ID of selection: [_1]",1000);
ok($result eq "ID of selection: 1.000") or print "Bail out! Failed numeric DOT-formatted (got: $result)\n";

$mp->numeric_format(Locale::MakePhrase::NUMERIC_FORMAT_NONE);
$result = $mp->translate("ID of selection: [_1]",1000);
ok($result eq "ID of selection: 1000") or print "Bail out! Failed numeric NON-formatted (got: $result)\n";

$mp->numeric_format(Locale::MakePhrase::NUMERIC_FORMAT_COMMA);
$result = $mp->translate("ID of selection: [_1]",1000);
ok($result eq "ID of selection: 1,000") or print "Bail out! Failed numeric COMMA-formatted (got: $result)\n";



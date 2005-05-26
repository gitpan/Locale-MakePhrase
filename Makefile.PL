use ExtUtils::MakeMaker;
WriteMakefile(
  'NAME' => 'Locale::MakePhrase',
  'AUTHOR' => 'Mathew Robertson',
  'VERSION' => '0.4',
  'ABSTRACT' => 'Language translation',
  'dist' => { COMPRESS => 'gzip -9f' },
);

sub MY::postamble { return <<'MAKE_FRAG';
cover:
	cover -delete
	HARNESS_PERL_SWITCHES=-MDevel::Cover make test
	cover

MAKE_FRAG
}



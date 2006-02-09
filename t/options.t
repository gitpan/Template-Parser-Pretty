#!perl

use strict;
use warnings;

use Test::More tests => 10;
use Template;
use Template::Parser::Pretty;

my (%parser, %want);

$parser{''}    = Template::Parser::Pretty->new();
$parser{'0_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 0);
$parser{'0_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 1);
$parser{'0_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 2);
$parser{'1_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 0);
$parser{'1_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 1);
$parser{'1_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 2);
$parser{'2_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 0);
$parser{'2_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 1);
$parser{'2_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 2);

$want{''}    = '|.|';
$want{'0_0'} = '|\s\f\r\n\t.\s\f\r\n\t|';
$want{'0_1'} = '|\s\f\r\n\t.|';
$want{'0_2'} = '|\s\f\r\n\t.\s|';
$want{'1_0'} = '|.\s\f\r\n\t|';
$want{'1_1'} = '|.|';
$want{'1_2'} = '|.\s|';
$want{'2_0'} = '|\s.\s\f\r\n\t|';
$want{'2_1'} = '|\s.|';
$want{'2_2'} = '|\s.\s|';

my $space			= ' ';
my $form_feed		= "\f";
my $carriage_return = "\r";
my $newline 		= "\n";
my $tab 			= "\t";
my $whitespace 		= "$space$form_feed$carriage_return$newline$tab";
my $key;

my %map = (
	" "		=> '\s',
	"\f" 	=> '\f',
	"\r" 	=> '\r',
	"\n" 	=> '\n',
	"\n" 	=> '\n',
	"\t" 	=> '\t'
);

my $t2 = "|$whitespace\[% '.' %]$whitespace|"; 

for my $key (sort keys %parser) {
	my $config = { PARSER => $parser{$key} };
	my $template = Template->new($config);
	my ($pre, $post) = $key ? split ('_', $key) : ('undef', 'undef');
	my $got = '';

	$template->process(\$t2, {}, \$got) || die $template->error();
	$got =~ s/(\s)/$map{$1}/eg;

	ok($got eq $want{$key}, "PRE_CHOMP => $pre, POST_CHOMP => $post");
}

#!perl

use strict;
use warnings;

use Test::More tests => 33;
use Template;
use Template::Parser::Pretty;

my (%parser, %want);

$parser{'?_?'} = Template::Parser::Pretty->new();
$parser{'0_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 0);
$parser{'0_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 1);
$parser{'0_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 2);
$parser{'0_3'} = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 3);
$parser{'1_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 0);
$parser{'1_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 1);
$parser{'1_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 2);
$parser{'1_3'} = Template::Parser::Pretty->new(PRE_CHOMP => 1, POST_CHOMP => 3);
$parser{'2_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 0);
$parser{'2_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 1);
$parser{'2_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 2);
$parser{'2_3'} = Template::Parser::Pretty->new(PRE_CHOMP => 2, POST_CHOMP => 3);
$parser{'3_0'} = Template::Parser::Pretty->new(PRE_CHOMP => 3, POST_CHOMP => 0);
$parser{'3_1'} = Template::Parser::Pretty->new(PRE_CHOMP => 3, POST_CHOMP => 1);
$parser{'3_2'} = Template::Parser::Pretty->new(PRE_CHOMP => 3, POST_CHOMP => 2);
$parser{'3_3'} = Template::Parser::Pretty->new(PRE_CHOMP => 3, POST_CHOMP => 3);

$want{'?_?'} = '|.|';
$want{'0_0'} = '|\s\f\r\n\t.\s\f\r\n\t|';
$want{'0_1'} = '|\s\f\r\n\t.\f\r\n\t|';
$want{'0_2'} = '|\s\f\r\n\t.\s\f\r\n\t|';
$want{'0_3'} = '|\s\f\r\n\t.|';
$want{'1_0'} = '|\s\f\r.\s\f\r\n\t|';
$want{'1_1'} = '|\s\f\r.\f\r\n\t|';
$want{'1_2'} = '|\s\f\r.\s\f\r\n\t|';
$want{'1_3'} = '|\s\f\r.|';
$want{'2_0'} = '|\s\f\r\s.\s\f\r\n\t|';
$want{'2_1'} = '|\s\f\r\s.\f\r\n\t|';
$want{'2_2'} = '|\s\f\r\s.\s\f\r\n\t|';
$want{'2_3'} = '|\s\f\r\s.|';
$want{'3_0'} = '|.\s\f\r\n\t|';
$want{'3_1'} = '|.\f\r\n\t|';
$want{'3_2'} = '|.\s\f\r\n\t|';
$want{'3_3'} = '|.|';

my $space			= ' ';
my $form_feed		= "\f";
my $carriage_return = "\r";
my $newline 		= "\n";
my $tab 			= "\t";
my $whitespace 		= "$space$form_feed$carriage_return$newline$tab";
my @chomps			= sort keys %parser;

my %whitespace_map = (
	" "		=> '\s',
	"\f" 	=> '\f',
	"\r" 	=> '\r',
	"\n" 	=> '\n',
	"\n" 	=> '\n',
	"\t" 	=> '\t'
);

my %option_map = (
	'0'	=> '+',	
	'1'	=> '-',	
	'2'	=> '',	
	'3'	=> '~',
	'?'	=> ''	
);

########################## constructor args ######################

my $arg_template = "|$whitespace\[% '.' %]$whitespace|"; 

for my $key (@chomps) {
	my $config = { PARSER => $parser{$key} };
	my $template = Template->new($config);
	my ($pre, $post) = $key ? split ('_', $key) : ('?', '?');
	my $got = '';

	$template->process(\$arg_template, {}, \$got) || die $template->error();
	$got =~ s/(\s)/$whitespace_map{$1}/eg;

	ok($got eq $want{$key}, "arg: PRE_CHOMP => $pre, POST_CHOMP => $post");
}

########################## directive options ######################

my $default =  Template->new({ PARSER => $parser{'0_0'} });
my %special = (
	'2_2'	=> Template->new({ PARSER => $parser{'2_2'} }),
);

for (0, 1, 3) {
	$special{"2_$_"} = Template->new({ PARSER => $parser{'2_0'} });
	$special{"$_\_2"} = Template->new({ PARSER => $parser{'0_2'} });
}

# For directives, ('?', '?') (i.e. undef, undef) is equivalent to (0, 0)
# rather than the (3, 3) defaults the parser uses, so we pop this test
# as there's already a test for (0, 0), and PRE_CHOMP => undef,
# POST_CHOMP => undef is not equivalent to a pair of undefined options: [% ... %]

pop @chomps;

for my $key (@chomps) {
	my ($pre_chomp, $post_chomp) = split ('_', $key); 
	my ($pre_option, $post_option) = @option_map{$pre_chomp, $post_chomp}; 
	my $option_template = "|$whitespace\[%$pre_option '.' $post_option%]$whitespace|"; 
	my ($got, $args) = ('', '');
	my $template;

	if ($template = $special{"$pre_chomp\_$post_chomp"}) {
		my @args = ();
		push @args, 'PRE_CHOMP => 2' if ($pre_chomp == 2);
		push @args, 'POST_CHOMP => 2' if ($post_chomp == 2);
		$args = join (', ', @args) . ' ';
	} else {
		$template = $default; 
	}

	$template->process(\$option_template, {}, \$got) || die $template->error();
	$got =~ s/(\s)/$whitespace_map{$1}/eg;

	ok($got eq $want{$key}, "option: ${args}pre => $pre_chomp ('$pre_option'), post => $post_chomp ('$post_option')");
}

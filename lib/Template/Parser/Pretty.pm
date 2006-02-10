package Template::Parser::Pretty;

require 5.004;

use strict;
use warnings;

use vars qw($VERSION $CHOMP_OPTION);
use base qw(Template::Parser);

use constant CHOMP_KILL => 3;

use Template::Constants qw(:chomp);

$VERSION = '0.90';

$CHOMP_OPTION = {
	'+'	=> CHOMP_NONE,
	'-'	=> CHOMP_ALL,
	'~'	=> CHOMP_KILL
};

sub new {
    my $class = shift;
    my $config = ($_[0] && UNIVERSAL::isa($_[0], 'HASH')) ? shift : { @_ };

    $config->{PRE_CHOMP}  = CHOMP_KILL unless (defined $config->{PRE_CHOMP});
    $config->{POST_CHOMP} = CHOMP_KILL unless (defined $config->{POST_CHOMP});

    return $class->SUPER::new($config);
}

#------------------------------------------------------------------------
# split_text($text)
#
# Split input template text into directives and raw text chunks.
#------------------------------------------------------------------------

sub split_text {
    my ($self, $text) = @_;
    my ($pre, $dir, $prelines, $dirlines, $postlines, $tags, @tags);
    my $style = $self->{STYLE}->[-1];
    my ($start, $end, $prechomp, $postchomp, $interp) = @$style{qw(START_TAG END_TAG PRE_CHOMP POST_CHOMP INTERPOLATE)};
    my @tokens = ();
    my $line = 1;

    return \@tokens unless ((defined $text) && (length $text));

    # extract all directives from the text
    my $directive_regex = qr{
        ^(.*?)          # $1 - start of line up to directive
         (?:
            $start      # start of tag
            (.*?)       # $2 - tag contents
            $end        # end of tag
         )
    }sx;

    while ($text =~ s/$directive_regex//s) {
        ($pre, $dir) = map { defined $_ ? $_ : '' } ($1, $2);
        $postlines = 0; # denotes lines chomped
        $prelines = ($pre =~ tr/\n//); # NULL - count only
        $dirlines = ($dir =~ tr/\n//); # ditto

        # the CHOMP directive's options may modify the preceding text
        for ($dir) {
            s/^([-+~\#])?\s*//s; # remove leading whitespace and check for a '-' chomp flag

            if ($1 && ($1 eq '#')) {
                $dir = ($dir =~ /([-+~])$/) ? $1 : ''; # comment out entire directive except for any chomp flag
            } else {
                # Template::Parser::Pretty 
				my $chomp = $1 ? $CHOMP_OPTION->{$1} : $prechomp;
                my $space = $prechomp == CHOMP_COLLAPSE ? ' ' : '';
				my $leading_whitespace_regex = $chomp == CHOMP_KILL ? qr{(\s+)$} : qr{((?:\n?[ \t]+)|\n)$};

                if ($chomp && ($pre =~ /$leading_whitespace_regex/)) {
                    my $leading_whitespace = $1;

                    # remove (or collapse) the selected whitespace before the directive
                    $pre =~ s/$leading_whitespace_regex/$space/;
                }
            }

            s/\s*([-+~])?\s*$//s; # remove trailing whitespace and check for a '-' chomp flag

			my $chomp = $1 ? $CHOMP_OPTION->{$1} : $postchomp;
			my $space = $postchomp == CHOMP_COLLAPSE ? ' ' : '';
			my $trailing_whitespace_regex = $chomp == CHOMP_KILL ? qr{^(\s+)} : qr{^((?:[ \t]+\n?)|\n)};

            # Template::Parser::Pretty 
            if ($chomp && ($text =~ /$trailing_whitespace_regex/)) {
                my $trailing_whitespace = $1;

                # increment the line counter if necessary
                $postlines += ($trailing_whitespace =~ tr/\n/\n/); 

                # now remove (or collapse) the selected whitespace after the directive
                $text =~ s/$trailing_whitespace_regex/$space/;
            }
        }

        # any text preceding the directive can now be added
        if (length $pre) {
            push (@tokens, $interp ? [ $pre, $line, 'ITEXT' ] : ('TEXT', $pre));
        }

        # Template::Parser::Pretty 
        # moved out of the preceding conditional: we might have outstanding newlines
        # to account for even if $pre is now zero length
        $line += $prelines;

        # and now the directive, along with line number information
        if (length $dir) {
            # the TAGS directive is a compile-time switch
            if ($dir =~ /^TAGS\s+(.*)/i) {
                my @tags = split(/\s+/, $1);

                if (scalar @tags > 1) {
                    ($start, $end) = map { quotemeta($_) } @tags;
                } elsif ($tags = $self->SUPER::TAG_STYLE->{$tags[0]}) {
                    ($start, $end) = @$tags;
                } else {
                    warn "invalid TAGS style: $tags[0]\n";
                }
            } else {
                # DIRECTIVE is pushed as: [ $dirtext, $line_no(s), \@tokens ]
                push @tokens, [
                    $dir,
                    ($dirlines ? sprintf("%d-%d", $line, $line + $dirlines) : $line),
                    $self->tokenise_directive($dir)
                ];
            }
        }

        # update line counter to include directive lines and any extra
        # newline chomped off the start of the following text
        $line += $dirlines + $postlines;
    }

    # anything remaining in the string is plain text 
    push (@tokens, $interp ? [ $text, $line, 'ITEXT' ] : ('TEXT', $text))
        if (length $text);

    return \@tokens;
}
    
1;

__END__

=head1 NAME

Template::Parser::Pretty - reader/writer friendly chomping for T2 templates

=head1 SYNOPSIS

    use Template;
    use Template::Parser::Pretty;

    my $parser = Template::Parser::Pretty->new();

        # or, equivalently

    my $parser = Template::Parser::Pretty->new(
        PRE_CHOMP    => 3,
        POST_CHOMP   => 3
    );

    my $config = {
        PARSER       => $parser
        ...
    };

    my $template = Template->new($config);

    $template->process(...) || die $template->error();

=head1 DESCRIPTION

It's easy to write readable templates in L<Template::Toolkit|Template Toolkit>, and it's easy to exercise
fine-grained control over the output of Template Toolkit templates. Achieving both at the same time, however,
can be tricky given the default parser's whitespace chomping rules, which consume no more than one newline
character on either side of a directive.

This means that templates optimized for readability (and writability) may be obliged to compromise
the indentation and spacing of the output and I<vice versa>. 

This module allows templates to be laid out in the most readable way, while enhancing control over spacing
by consuming I<all> whitespace (including newlines) before and after directives (unless overridden by the
customary C<+> and C<-> prefix and postfix options).

The old chomping behaviour can be enabled on a per-directive basis in templates that default to
greedy chomping (as Template::Parser::Pretty templates do if no PRE_CHOMP or POST_CHOMP values are supplied).
Likewise, greedy chomping can be selectively enabled in non-greedy templates by using a new directive option,
C<~>, corresponding to the new default PRE_CHOMP/POST_CHOMP value of 3.

e.g.

    my $parser = Template::Parser::Pretty->new(
        PRE_CHOMP    => 2,
        POST_CHOMP   => 0
    );

    my $config = { PARSER => $parser };

And, in the template:

    [BLOCK foo %]

        [%- IF 1 ~%]

            bar

        [%~ END +%]

    [% END %]

In this example, the C<~> directive consumes all of the whitespace around the embedded text, and is
thus equivalent to:

    [%- IF 1 %]bar[% END +%]

The C<+> directive at the end of the C<IF> block turns on C<CHOMP_NONE> (0) for the suffixed whitespace,
which is therefore not chomped; and the C<-> directive at the beginning of the C<IF> performs
a CHOMP_COLLAPSE (2) chomp, which collapses the indentation and one newline to a single space,
but leaves the whitespace before that intact.

As with the default parser, any whitespace I<inside> the preceding or following text is preserved,
so boilerplate only needs to concern itself with its surrounding whitespace.

This leaves indentation and newlines under the explicit control of the template author, by any of the
mechanisms available in the Template technician's toolkit e.g. by using explicit newline and
indentation directives:

    [% nl = "\n" %]

    [% BLOCK foo %] [%# params: bar, indent %]
        [% outer = tab(indent) %]
        [% inner = tab(add(indent, 1)) %]
        [% outer %]

        <foo>
            [% FOR baz IN bar %]

                [% nl %] [% inner %]
                <bar baz="[% baz %]" />

            [% END %] [% nl %] [% outer %]
        </foo>
        
    [% END %]

Or by selectively turning off left and/or right chomping:

    [% IF 1 +%]

        ------------------------------------
        | alpha | beta | gamma | vlissides |
        ------------------------------------
        |  foo  | bar  |  baz  |    quux   |
        ------------------------------------

    [%+ END %]

Note that I<all> whitespace characters are chomped (i.e. [\r\n\f\t ]), including carriage
returns, which Template::Parser leaves unchaperoned (see L<Template::Parser::LocalizeNewlines>),
so this module does the right thing on non-Unix platforms.

=head1 SEE ALSO

=over

=item * L<Template|Template> 

=item * L<Template::Parser::LocalizeNewlines|Template::Parser::LocalizeNewlines>

=item * http://www.mail-archive.com/templates@template-toolkit.org/msg07575.html

=item * http://www.mail-archive.com/templates@template-toolkit.org/msg07659.html

=back

=head1 VERSION

0.90

=head1 AUTHOR

chocolateboy E<lt>chocolate.boy@email.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by chocolateboy

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

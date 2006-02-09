package Template::Parser::Pretty;

require 5.004;

use strict;
use warnings;

use base qw(Template::Parser);

our $VERSION = 0.02;

sub new {
    my $class = shift;
    my $config = ($_[0] && UNIVERSAL::isa($_[0], 'HASH')) ? shift : { @_ };

    $config->{PRE_CHOMP}  = 1 unless (defined $config->{PRE_CHOMP});
    $config->{POST_CHOMP} = 1 unless (defined $config->{POST_CHOMP});

    return $class->SUPER::new($config);
}

#------------------------------------------------------------------------
# split_text($text)
#
# Split input template text into directives and raw text chunks.
#------------------------------------------------------------------------

sub split_text {
    my ($self, $text) = @_;
    my ($pre, $dir, $prelines, $dirlines, $postlines, $chomp, $tags, @tags);
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
            s/^([-+\#])?\s*//s; # remove leading whitespace and check for a '-' chomp flag

            if ($1 && ($1 eq '#')) {
                $dir = ($dir =~ /([-+])$/) ? $1 : ''; # comment out entire directive except for any chomp flag
            } else {
                $chomp = ($1 && ($1 eq '+')) ? 0 : ($1 || $prechomp);
                my $space = $prechomp == $self->SUPER::CHOMP_COLLAPSE ? ' ' : '';

                # Template::Parser::Pretty 
                if ($chomp && ($pre =~ /(\s+)$/)) {
                    my $pre_whitespace = $1;

                    # remove (or collapse) *all* whitespace before the directive
                    $pre =~ s/\s+$/$space/;
                }
            }

            s/\s*([-+])?\s*$//s; # remove trailing whitespace and check for a '-' chomp flag

            $chomp = ($1 && ($1 eq '+')) ? 0 : ($1 || $postchomp);

            my $space = ($postchomp == &Template::Constants::CHOMP_COLLAPSE) ? ' ' : '';

            # Template::Parser::Pretty 
            if ($chomp && ($text =~ /^(\s+)/)) {
                my $post_whitespace = $1;

                # increment the line counter if necessary
                $postlines += ($post_whitespace =~ tr/\n/\n/); 

                # now remove (or collapse) *all* whitespace after the directive
                $text =~ s/^\s+/$space/;
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

    my $config = {
        INCLUDE_PATH    => '.',
        PARSER          => Template::Parser::Pretty->new()
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
by consuming B<all> whitespace (including newlines) before and after directives (unless overridden by the
customary C<+> and C<-> prefix and postfix options).

As with the default parser, any whitespace B<inside> the preceding or following text is preserved,
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

Note that B<all> whitespace characters are chomped (i.e. [\r\n\f\t ]), including carriage
returns, which C<Template::Parser> leaves unchaperoned (see L<Template::Parser::LocalizeNewlines>),
so this module does the right thing on non-Unix platforms.

By default, C<Template::Parser::Pretty> sets C<PRE_CHOMP> and C<POST_CHOMP> to 1. Either or both of these
can be overridden by passing 0 (no chomping) or 2 (collapse to a single space) as constructor
arguments e.g.

    my $parser = Template::Parser::Pretty->new(PRE_CHOMP => 0, POST_CHOMP => 2);

    my $config = {
        INCLUDE_PATH  => '.',
        PARSER        => $parser
    };

    my $template = Template->new($config);

    $template->process(...);

=head1 SEE ALSO

=over

=item * L<Template|Template> 

=item * L<Template::Parser::LocalizeNewlines|Template::Parser::LocalizeNewlines>

=item * http://www.mail-archive.com/templates@template-toolkit.org/msg07575.html

=item * http://www.mail-archive.com/templates@template-toolkit.org/msg07659.html

=back

=head1 VERSION

0.02

=head1 AUTHOR

chocolateboy E<lt>chocolate.boy@email.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by chocolateboy

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

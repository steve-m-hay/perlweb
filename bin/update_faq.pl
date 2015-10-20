#!/usr/bin/perl

=head1 NAME

update_faq.pl - Converts Pod to HTML for the /faq/ section

=head1 DESCRIPTION

Downloads the latest perlfaq from metacpan and generates out
the pages. This will be run manually.

Uses Pod::Simple::XHTML to convert Pod to HTML.

=cut

use strict;
use warnings;

use Cwd;
use Path::Class;
use LWP::Simple;
use File::Copy;

# use File::Copy;
# use File::Copy::Recursive qw(dircopy);
use Pod::Simple::XHTML;
use JSON;

my ( $latest_name, $latest_version ) = fetch_latest_perlfaq();

# constants
my $SOURCE             = '/tmp/' . $latest_name . '/lib';
my $DESTINATION        = './docs/learn/faq/';
my $HTML_CHARSET       = 'UTF-8';
my $PERLDOC_URL_PREFIX = 'https://metacpan.org/module/';

{
    my $source      = Path::Class::Dir->new($SOURCE);
    my $destination = Path::Class::Dir->new($DESTINATION);
    -d $destination or die "$destination does not exist";

    while ( my $pod_file = $source->next ) {
        next unless $pod_file->stringify =~ /.pod$/;

        my $parser = Pod::Simple::XHTML->new;
        $parser->html_header( page_header() );
        $parser->html_footer('<p><em>Version: --perlfaq_version--</em></p></div>');
        $parser->html_charset($HTML_CHARSET);
        $parser->index( $pod_file->stringify =~ /perlfaq.pod$/ ? 0 : 1 );
        $parser->perldoc_url_prefix($PERLDOC_URL_PREFIX);

        my $html = '';
        $parser->output_string( \$html );

        $parser->parse_file( $pod_file->stringify );

        my $basename = $pod_file->basename;
        $basename =~ s/.pod$//;

        $html =~ s/--page_name--/$basename/g;
        $html =~ s/--perlfaq_version--/$latest_version/g;

        # Add the .html to our perlfaq pages
        $html =~ s{perlfaq(\d*?)">}{perlfaq$1.html">}g;

        # Might be linking to a section
        $html =~ s{perlfaq(\d*?)#(.+?)">}{perlfaq$1.html#$2">}g;

        $html =~ s!(${PERLDOC_URL_PREFIX}perlfaq)!perlfaq!g;

        # Remove code blocks if we have a <pre> as well
        # because we'll be syntax hilighting them
        $html =~ s/<pre><code>/<pre>/g;
        $html =~ s{</code></pre>}{</pre>}g;

        # Style up our pre tags so we can do syntax hilighting
        $html
            =~ s/<pre>/<pre class="brush: pl; class-name: 'highlight'; toolbar: false; gutter: false">/g;

        # Make anything that is a URL a link
        #$html = markup_links( text => $html, handler => \&decorate_link );

        my $html_file
            = Path::Class::File->new( $destination, $basename . '.html' );
        my $fh = $html_file->openw or die "can't open $html_file: $!";
        print $fh $html;
        close $fh;
    }

    # dircopy( "static", $destination->subdir('static')->stringify );
}

#
# sub decorate_link {
#     my ( $url, $left, $right ) = @_;
#
#     # Skip already marked links.
#     return $url if ( $left  =~ /href=["']$/ );
#     return $url if ( $right =~ qr|^</a>| );
#
#     # HACK: we don't want to decorate links that
#     # are in <pre> tags - so look line by line for
#     # backup the source to see if the last tag was <pre...>
#     my @lines = reverse split "\n", $left;
#     foreach my $line (@lines) {
#         if ( $line =~ /\<.+\>/ ) {
#             if ( $line =~ /<pre.+>/ ) {
#
#                 # There was a start pre tag before this url, so don't like
#                 return $url;
#             } else {
#
#                 # must be some other tag so decorate
#                 last;
#             }
#         }
#     }
#
#     my $label = $url;
#     $url = "http://$url" if ( $url =~ /^www/i );
#     return qq|<a href="$url">$label</a>|;
# }

sub page_header {
    return '[%# DO NOT EDIT THIS FILE: generated from perlfaq (https://github.com/perl-doc-cats/perlfaq) -%]
    [%-
        # Used to get info from htmlify to ttree
        page.import({
            title    => "--page_name--",
            section  => "faq",
            description
                => "Perl Frequently Asked Questions, Perl FAQ",
            keywords => "perl, perl faq, perlfaq"
        });
        perlfaq_version = --perlfaq_version--;
    -%]
    <div class="pod">'
        ;
}

sub fetch_latest_perlfaq {

    my $local_name;
    my $local_version;

    my $tmp_file = "/tmp/perlfaq.tar.gz";

    if($ARGV[0] && $ARGV[0] =~ /gz$/) {
        my $zip = file($ARGV[0]);
        $local_name = $zip->basename();
        $local_name =~ s/\.tar\.gz$//;
        $local_version = $local_name;
        $local_version =~ s/^perlfaq-//;

        copy( $zip->stringify, $tmp_file);

    } else {
        my $json = JSON->new();

        my $latest_meta_source = get('http://api.metacpan.org/release/perlfaq');
        my $latest_meta        = $json->decode($latest_meta_source);
        my $download_url       = $latest_meta->{download_url};
warn $download_url;
        mirror( $download_url, $tmp_file );

        # Back to previous dir please
        $local_name = $latest_meta->{name};
        $local_version = $latest_meta->{version};

    }

    my $cwd = getcwd();
    chdir '/tmp/';
    system('tar -xzf perlfaq.tar.gz');
    chdir $cwd;
    return $local_name, $local_version;



}

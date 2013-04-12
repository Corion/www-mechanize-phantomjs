package WWW::Mechanize::WebDriver;
use strict;
use Selenium::Remote::Driver;
use WWW::Mechanize::Plugin::Selector;

sub new {
    my ($class, %options) = @_;
    
    $options{ port } ||= 4446;
    
    # XXX Need autodie
    
    # Launch PhantomJs
    $options{ launch_exe } ||= 'phantomjs';
    $options{ launch_arg } ||= [ "--webdriver=$options{ port }", "--webdriver-loglevel=ERROR",];
    my $cmd= "| $options{ launch_exe } @{ $options{ launch_arg } }";
    $options{ pid } ||= open my $fh, $cmd
        or die "Couldn't launch [$cmd]: $! / $?";
    $options{ fh } = $fh;
    
    # Connect to it
    $options{ driver } ||= Selenium::Remote::Driver->new(
        'port' => $options{ port },
        auto_close => 1,
     );
     
     bless \%options => $class;
};

sub driver {
    $_[0]->{driver}
};

sub DESTROY {
    kill 9 => $_[0]->{ pid }
}

sub get {
    my ($self, $url) = @_;
    $self->driver->get( $url );
    # XXX Need to return a HTTP::Response
};

sub decoded_content {
    $_[0]->driver->get_page_source
};

sub content {
    $_[0]->driver->get_page_source
};

sub title {
    $_[0]->driver->get_title;
};

=head2 C<< $mech->selector( $css_selector, %options ) >>

  my @text = $mech->selector('p.content');

Returns all nodes matching the given CSS selector. If
C<$css_selector> is an array reference, it returns
all nodes matched by any of the CSS selectors in the array.

This takes the same options that C<< ->xpath >> does.

This method is implemented via L<WWW::Mechanize::Plugin::Selector>.

=cut

*selector = \&WWW::Mechanize::Plugin::Selector::selector;

sub xpath {
    my( $self, $query, %options) = @_;

    # XXX Determine if we want only one element
    #     or a list, like WWW::Mechanize::Firefox
    $_[0]->driver->find_elements($query);
}

1;

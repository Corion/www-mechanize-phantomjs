package WWW::Mechanize::WebDriver;
use strict;

use Selenium::Remote::Driver;

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

sub title {
    $_[0]->driver->get_title;
};

1;
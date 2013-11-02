package WWW::Mechanize::WebDriver;
use strict;
use Selenium::Remote::Driver;
use WWW::Mechanize::Plugin::Selector;
use HTTP::Response;
use HTTP::Headers;
use Scalar::Util qw( blessed );

use vars qw($VERSION);
$VERSION= '0.01';

=head1 NAME

WWW::Mechanize::WebDriver - automate a Selenium webdriver capable browser

=cut

sub new {
    my ($class, %options) = @_;
    
    $options{ port } ||= 4446;
    
    # XXX Need autodie
    
    # Launch PhantomJs
    $options{ launch_exe } ||= 'phantomjs';
    $options{ launch_arg } ||= [ "--webdriver=$options{ port }", #"--webdriver-loglevel=ERROR",
                               ];
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

sub events { [] };

sub DESTROY {
    if( my $dr= delete ${ $_[0]}{ driver }) {
        $dr->quit;
    };
    kill 9 => $_[0]->{ pid }
}

=head1 NAVIGATION METHODS

=head2 C<< $mech->get( $url, %options ) >>

  $mech->get( $url, ':content_file' => $tempfile );

Retrieves the URL C<URL>.

It returns a faked L<HTTP::Response> object for interface compatibility
with L<WWW::Mechanize>. It seems that Selenium and thus L<Selenium::Remote::Driver>
have no concept of HTTP status code and thus no way of returning the
HTTP status code.

Recognized options:

=over 4

=item *

C<< :content_file >> - filename to store the data in

=item *

C<< no_cache >> - if true, bypass the browser cache

=back

=cut

sub update_response {
    my( $self, $phantom_res ) = @_;

    my @headers= map {;%$_} @{ $phantom_res->{headers} };
    my $res= HTTP::Response->new( $phantom_res->{status}, $phantom_res->{statusText}, \@headers );

    # XXX should we fetch the response body?!

    $self->{response} = $res
};

sub get {
    my ($self, $url, %options ) = @_;
    # We need to stringify $url so it can pass through JSON
    my $phantom_res= $self->driver->get( "$url" );

    $self->update_response( $phantom_res );
};

# If things get nasty, we could fall back to PhantomJS.webpage.plainText
# var page = require('webpage').create();
# page.open('http://somejsonpage.com', function () {
#     var jsonSource = page.plainText;
sub decoded_content {
    $_[0]->driver->get_page_source
};

sub content {
    $_[0]->driver->get_page_source
};

sub title {
    $_[0]->driver->get_title;
};

sub response { $_[0]->{response} };
*res = \&response;

=head2 C<< $mech->back( [$synchronize] ) >>

    $mech->back();

Goes one page back in the page history.

Returns the (new) response.

=cut

sub back {
    my ($self, $synchronize) = @_;
    $synchronize ||= (@_ != 2);
    if( !ref $synchronize ) {
        $synchronize = $synchronize
                     ? $self->events
                     : []
    };
    
    $self->_sync_call($synchronize, sub {
        $self->driver->go_back;
    });
}

=head2 C<< $mech->forward( [$synchronize] ) >>

    $mech->forward();

Goes one page forward in the page history.

Returns the (new) response.

=cut

sub forward {
    my ($self, $synchronize) = @_;
    $synchronize ||= (@_ != 2);
    if( !ref $synchronize ) {
        $synchronize = $synchronize
                     ? $self->events
                     : []
    };
    
    $self->_sync_call($synchronize, sub {
        $self->driver->go_forward;
    });
}

=head2 C<< $mech->uri() >>

    print "We are at " . $mech->uri;

Returns the current document URI.

=cut

sub uri {
    URI->new( $_[0]->driver->get_current_url )
}

=head2 C<< $mech->success() >>

    $mech->get('http://google.com');
    print "Yay"
        if $mech->success();

Returns a boolean telling whether the last request was successful.
If there hasn't been an operation yet, returns false.

This is a convenience function that wraps C<< $mech->res->is_success >>.

=cut

sub success {
    my $res = $_[0]->response( headers => 0 );
    $res and $res->is_success
}

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
    
    if ('ARRAY' ne (ref $query||'')) {
        $query = [$query];
    };

    my $single = $options{ single };
    my $first  = $options{ one };
    my $maybe  = $options{ maybe };
    my $any    = $options{ any };
    my $return_first_element = ($single or $first or $maybe or $any );

    # Construct some helper variables
    my $zero_allowed = not ($single or $first);
    my $two_allowed  = not( $single or $maybe);

    # Sanity check for the common error of
    # my $item = $mech->xpath("//foo");
    if (! exists $options{ all } and not ($return_first_element)) {
        $self->signal_condition(join "\n",
            "You asked for many elements but seem to only want a single item.",
            "Did you forget to pass the 'single' option with a true value?",
            "Pass 'all => 1' to suppress this message and receive the count of items.",
        ) if defined wantarray and !wantarray;
    };

    # XXX I fear we can only search within The One Document, and not
    #     conveniently within IFRAMEs etc.
    if ($options{ node }) {
        $options{ document } ||= $options{ node }->{ownerDocument};
    } else {
        $options{ node }= $self->driver->get_active_element;
        $options{ document } ||= $self->document;
    };

    # XXX Determine if we want only one element
    #     or a list, like WWW::Mechanize::Firefox

    # Now find the elements
    my @res= map { $self->driver->find_child_elements( $options{ node }, $_ => 'xpath' ) } @$query;

    if (! $zero_allowed and @res == 0) {
        $self->signal_condition( "No elements found for $options{ user_info }" );
    };

    if (! $two_allowed and @res > 1) {
        $self->highlight_node(@res);
        $self->signal_condition( (scalar @res) . " elements found for $options{ user_info }" );
    };

    $return_first_element ? $res[0] : @res

}

=head2 C<< $mech->click( $name [,$x ,$y] ) >>

  $mech->click( 'go' );
  $mech->click({ xpath => '//button[@name="go"]' });

Has the effect of clicking a button (or other element) on the current form. The
first argument is the C<name> of the button to be clicked. The second and third
arguments (optional) allow you to specify the (x,y) coordinates of the click.

If there is only one button on the form, C<< $mech->click() >> with
no arguments simply clicks that one button.

If you pass in a hash reference instead of a name,
the following keys are recognized:

=over 4

=item *

C<selector> - Find the element to click by the CSS selector

=item *

C<xpath> - Find the element to click by the XPath query

=item *

C<dom> - Click on the passed DOM element

You can use this to click on arbitrary page elements. There is no convenient
way to pass x/y co-ordinates with this method.

=item *

C<id> - Click on the element with the given id

This is useful if your document ids contain characters that
do look like CSS selectors. It is equivalent to

    xpath => qq{//*[\@id="$id"]}

=item *

C<synchronize> - Synchronize the click (default is 1)

Synchronizing means that WWW::Mechanize::Firefox will wait until
one of the events listed in C<events> is fired. You want to switch
it off when there will be no HTTP response or DOM event fired, for
example for clicks that only modify the DOM.

You can pass in a scalar that is a false value to not wait for
any kind of event.

Passing in an array reference will use the array elements as
Javascript events to wait for.

Passing in any other true value will use the value of C<< ->events >>
as the list of events to wait for.

=back

Returns a L<HTTP::Response> object.

As a deviation from the WWW::Mechanize API, you can also pass a 
hash reference as the first parameter. In it, you can specify
the parameters to search much like for the C<find_link> calls.

=cut

sub click {
    my ($self,$name,$x,$y) = @_;
    my %options;
    my @buttons;
    
    if (! defined $name) {
        croak("->click called with undef link");
    } elsif (ref $name and blessed($name) and $name->can('click')) {
        $options{ dom } = $name;
    } elsif (ref $name eq 'HASH') { # options
        %options = %$name;
    } else {
        $options{ name } = $name;
    };
    
    if (exists $options{ name }) {
        $name = quotemeta($options{ name }|| '');
        $options{ xpath } = [
                       sprintf( q{//*[(translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")="button" and @name="%s") or (translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")="input" and (@type="button" or @type="submit" or @type="image") and @name="%s")]}, $name, $name), 
        ];
        if ($options{ name } eq '') {
            push @{ $options{ xpath }}, 
                       q{//*[(translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz") = "button" or translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")="input") and @type="button" or @type="submit" or @type="image"]},
            ;
        };
        $options{ user_info } = "Button with name '$name'";
    };
    
    if (! exists $options{ synchronize }) {
        #$options{ synchronize } = $self->events;
    } elsif( ! ref $options{ synchronize }) {
        #$options{ synchronize } = $options{ synchronize }
        #                        ? $self->events
        #                        : [],
    };
    $options{ synchronize } ||= [];
    
    if ($options{ dom }) {
        @buttons = $options{ dom };
    } else {
        @buttons = $self->_option_query(%options);
    };
    
    $self->_sync_call(
        $options{ synchronize }, sub { # ,'abort'
            $buttons[0]->click();
        }
    );

    if (defined wantarray) {
        return $self->response
    };
}

# Internal convenience method for dipatching a call either synchronized
# or not
sub _sync_call {
    my ($self, $events, $cb) = @_;

    if (@$events) {
        $self->synchronize( $events, $cb );
    } else {
        $cb->();
    };    
};

=head2 C<< $mech->click_button( ... ) >>

  $mech->click_button( name => 'go' );
  $mech->click_button( input => $mybutton );

Has the effect of clicking a button on the current form by specifying its
name, value, or index. Its arguments are a list of key/value pairs. Only
one of name, number, input or value must be specified in the keys.

=over 4

=item *

C<name> - name of the button

=item *

C<value> - value of the button

=item *

C<input> - DOM node

=item *

C<id> - id of the button

=item *

C<number> - number of the button

=back

If you find yourself wanting to specify a button through its
C<selector> or C<xpath>, consider using C<< ->click >> instead.

=cut

sub click_button {
    my ($self,%options) = @_;
    my $node;
    my $xpath;
    my $user_message;
    if (exists $options{ input }) {
        $node = delete $options{ input };
    } elsif (exists $options{ name }) {
        my $v = delete $options{ name };
        $xpath = sprintf( '//*[(translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz") = "button" and @name="%s") or (translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")="input" and @type="button" or @type="submit" and @name="%s")]', $v, $v);
        $user_message = "Button name '$v' unknown";
    } elsif (exists $options{ value }) {
        my $v = delete $options{ value };
        $xpath = sprintf( '//*[(translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz") = "button" and @value="%s") or (translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")="input" and (@type="button" or @type="submit") and @value="%s")]', $v, $v);
        $user_message = "Button value '$v' unknown";
    } elsif (exists $options{ id }) {
        my $v = delete $options{ id };
        $xpath = sprintf '//*[@id="%s"]', $v;
        $user_message = "Button name '$v' unknown";
    } elsif (exists $options{ number }) {
        my $v = delete $options{ number };
        $xpath = sprintf '//*[translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz") = "button" or (translate(local-name(.), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz") = "input" and @type="submit")][%s]', $v;
        $user_message = "Button number '$v' out of range";
    };
    $node ||= $self->xpath( $xpath,
                          node => $self->current_form,
                          single => 1,
                          user_message => $user_message,
              );
    if ($node) {
        $self->click({ dom => $node, %options });
    } else {
        
        $self->signal_condition($user_message);
    };
    
}

sub current_form {
    my( $self, %options )= @_;
    # Find the first <FORM> element from the currently active element
    my $focus= $self->driver->get_active_element;
    
    if( !$focus ) {
        # XXX Signal the error
        return
    };
    
    $self->xpath( './/ancestor-or-self::FORM', node => $focus );
}

1;

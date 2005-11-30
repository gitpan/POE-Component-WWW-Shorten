package POE::Component::WWW::Shorten;

use strict;
use warnings;
use POE 0.31 qw(Wheel::Run Filter::Line Filter::Reference);
use vars qw($VERSION);
use Carp;

$VERSION = '1.00';

sub spawn {
  my ($package) = shift;
  croak "$package requires an even number of parameters" if @_ & 1;
  my %parms = @_;

  foreach my $key ( keys %parms ) {
	$parms{ lc $key } = delete $parms{$key};
  }

  delete ( $parms{'options'} ) unless ( ref ( $parms{'options'} ) eq 'HASH' );
  my $type = delete ( $parms{'type'} ) || 'Metamark';

  eval {
	require WWW::Shorten;
	import WWW::Shorten $type;
  };
  die "Problem loading WWw::Shorten \'$type\', please check\n" if ($@);

  my $self = bless \%parms, $package;

  $self->{session_id} = POE::Session->create(
	object_states => [
		$self => { shorten => '_shorten',
			   shutdown => '_shutdown',
		},
		$self => [ qw(_child_error _child_closed _child_stdout _child_stderr _start) ],
	],
	( defined ( $parms{'options'} ) ? ( options => $parms{'options'} ) : () ),
  )->ID();

  return $self;
}

sub _start {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  $self->{session_id} = $_[SESSION]->ID();
  if ( $self->{alias} ) {
	$kernel->alias_set( $self->{alias} );
  } else {
	$kernel->refcount_increment( $self->{session_id} => __PACKAGE__ );
  }

  $self->{wheel} = POE::Wheel::Run->new(
	Program => \&shorten_wheel,
	ErrorEvent => '_child_error',
	CloseEvent => '_child_closed',
	StdoutEvent => '_child_stdout', 
	StderrEvent => '_child_stderr',
	StdioFilter => POE::Filter::Reference->new(),
	StderrFilter => POE::Filter::Line->new(),
	( $^O eq 'MSWin32' ? ( CloseOnCall => 0 ) : ( CloseOnCall => 1 ) ),
  );

  unless ( $self->{wheel} ) {
	$kernel->yield( 'shutdown' );
  }
  undef;
}

sub session_id {
  return $_[0]->{session_id};
}

sub shorten {
  my ($self) = shift;
  $poe_kernel->post( $self->{session_id} => 'shorten' => @_ );
}

sub _shorten {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  my $sender = $_[SENDER]->ID();

  return if ( $self->{shutdown} );
  my $args;
  if ( ref( $_[ARG0] ) eq 'HASH' ) {
	$args = { %{ $_[ARG0] } };
  } else {
	warn "first parameter must be a hashref, trying to adjust. "
		."(fix this to get rid of this message)";
	$args = { @_[ARG0..$#_] };
  }

  foreach my $key ( keys %{ $args } ) {
	  next if ( $key =~ /^_/ );
	  $args->{ lc ( $key ) } = delete ( $args->{ $key } );
  }

  unless ( $args->{event} ) {
	warn "where am i supposed to send the output?";
	return;
  }

  unless ( $args->{url} ) {
	warn "No 'url' specified";
	return;
  }

  $args->{sender} = $sender;
  $kernel->refcount_increment( $sender => __PACKAGE__ );
  $self->{wheel}->put( $args );
  undef;
}

sub shutdown {
  my ($self) = shift;
  $poe_kernel->post( $self->{session_id} => 'shutdown' => @_ );
}

sub _shutdown {
  my ($kernel,$self) = @_[KERNEL,OBJECT];

  $kernel->alias_remove( $_ ) for $kernel->alias_list();

  unless ( $self->{alias} ) {
	$kernel->refcount_decrement( $self->{session_id} => __PACKAGE__ );
  }

  $self->{shutdown} = 1;
  $self->{wheel}->shutdown_stdin if ( $self->{wheel} );
  undef;
}

sub _child_closed {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  delete ( $self->{wheel} );
  $kernel->yield( 'shutdown' );
  undef;
}

sub _child_error {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  delete ( $self->{wheel} );
  $kernel->yield( 'shutdown' );
  undef;
}

sub _child_stderr {
  my ($kernel,$self,$input) = @_[KERNEL,OBJECT,ARG0];

  warn "$input\n" if ( $self->{debug} );
  undef;
}

sub _child_stdout {
  my ($kernel,$self,$input) = @_[KERNEL,OBJECT,ARG0];
  my ($session) = delete ( $input->{sender} );
  my ($event) = delete ( $input->{event} );

  $kernel->post( $session, $event, $input );
  $kernel->refcount_decrement( $session => __PACKAGE__ );
  undef;  
}

sub shorten_wheel {
  if ( $^O eq 'MSWin32' ) {
     binmode(STDIN); binmode(STDOUT);
  }
  my $raw;
  my $size = 4096;
  my $filter = POE::Filter::Reference->new();

  while ( sysread ( STDIN, $raw, $size ) ) {
    my $requests = $filter->get( [ $raw ] );
    foreach my $req ( @{ $requests } ) {
	_process_requests( $req, $filter );
    }
  }
}

sub _process_requests {
  my ($req,$filter) = @_;

  $req->{short} = makeashorterlink( $req->{url} );
  my $response = $filter->put( [ $req ] );
  print STDOUT @$response;
}

1;
__END__

=head1 NAME

POE::Component::WWW::Shorten - A non-blocking wrapper around L<WWW::Shorten>.

=head1 SYNOPSIS

  use POE qw(Component::WWW::Shorten);

  my $poco = POE::Component::WWW::Shorten->spawn( alias => 'shorten', type => 'Metamark' );

  POE::Session->create(
	package_states => [
		'main' => [ qw(_start _shortened) ],
	],
  );

  $poe_kernel->run();
  exit 0;

  sub _start {
	my ($kernel,$heap) = @_[KERNEL,HEAP];

	$kernel->post( 'shorten' => 'shorten' => 
	  { 
		url => 'http://reallyreallyreallyreally/long/url',
		event => '_shortened',
		_arbitary_value => 'whatever',
	  }
	);
	undef;
  }

  sub _shortened {
	my ($kernel,$heap,$returned) = @_[KERNEL,HEAP,ARG0];

	if ( $returned->{short} ) {
	   print STDOUT $returned->{short} . "\n";
	}

	print STDOUT $returned->{_arbitary_value} . "\n";
	undef;
  }

=head1 DESCRIPTION

POE::Component::WWW::Shorten is a L<POE> component that provides a non-blocking wrapper around
L<WWW::Shorten>. It accepts 'shorten' events and will return a shortened url.

If the type of shortening to do is not specified it uses the L<WWW::Shorten> default which is L<WWW::Shorten::Metamark>.

=head1 CONSTRUCTOR

=over

=item spawn

Takes a number of arguments all are optional. Returns an object.

  'alias', specify a POE Kernel alias for the component;
  'options', a hashref of POE Session options to pass to the component's session;
  'type', the WWW::Shorten sub module to use, default is 'Metamark';

=back

=head1 METHODS

These are for the OO interface to the component.

=over

=item shorten

Requires a hashref as first argument. See 'shorten' event below for details.

=item session_id

Takes no arguments. Returns the POE Session ID of the component.

=item shutdown

Takes no arguments, terminates the component.

=back

=head1 INPUT

What POE events our component will accept.

=over

=item shorten

Requires a hashref as first argument. The hashref should contain the following keyed values:

  'url', the url that you want shortening. ( Mandatory ).
  'event', the name of the event to send the reply to. ( Mandatory ).

You may also pass arbitary key/values in the hashref ( as demonstrated in the SYNOPSIS ). Arbitary keys should have an underscore prefix '_'.

=item shutdown

Takes no arguments, terminates the component.

=back

=head1 OUTPUT

Whether the OO or POE API is used the component passes responses back via a POE event. ARG0 will be a hashref with the following key/value pairs:

  'url', the url that you wanted shortening.
  'short', the shortened version. ( This will be undef if something went wrong ).
  
The hashref will also contain any arbitary key/values that were passed in the original query.

=head1 AUTHOR

Chris 'BinGOs' Williams

=head1 SEE ALSO

L<POE>, L<WWW::Shorten>

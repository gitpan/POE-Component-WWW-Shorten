use Test::More tests => 3;
BEGIN { use_ok('POE::Component::WWW::Shorten') };

use POE;

my $self = POE::Component::WWW::Shorten->spawn( options => { trace => 0 } );

isa_ok ( $self, 'POE::Component::WWW::Shorten' );

POE::Session->create(
        inline_states => { _start => \&test_start, },
);

$poe_kernel->run();
exit 0;

sub test_start {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  pass('blah');
  $self->shutdown();
  undef;
}

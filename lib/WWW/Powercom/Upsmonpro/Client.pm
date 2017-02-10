package WWW::Powercom::Upsmonpro::Client;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Cookies;
use HTTP::Response;
use Carp;
use Class::Accessor 'moose-like';

has ua            => (is => 'ro');
has req           => (is => 'ro');
has url           => (is => 'ro');
has error         => (is => 'ro');
has status_format => (is => 'ro');
has switch_on     => (is => 'ro');
has switch_off    => (is => 'ro');

our $errstr;

our $DEFAULT_UPS_PAGE           = '/ups.txt';
our $DEFAUL_UPS_WEB_SERVER_PORT = '8000';
our $RAW_STATUS_LENGTH          = 46;
our $DEFAULT_FORMAT =
  "Input Voltage: %input_voltage\nOutput Voltage: %output_voltage\nLoad: %load_level%%\nTemp: %temp\nLine: %on_off_line";
our $DEFAULT_SWITCH_FORMAT = 'On/Off';

my %SWITCH_LIST = map { ($_, 1) } qw/utility battery_low bypass_avr ups_failed on_off_line test shutdown_active beeper/;

my @UPS_STATUS_VOCUBLARY = (
  { code => 'substr($raw_status_line, 1, 3)',                name => 'Input Voltage',    key => 'input_voltage' },
  { code => 'substr($raw_status_line, 13,3)',                name => 'Output Voltage',   key => 'output_voltage' },
  { code => 'sprintf("%d", substr($raw_status_line, 19,3))', name => 'Load Level',       key => 'load_level' },
  { code => 'substr($raw_status_line, 23,2)',                name => 'Input Frequency',  key => 'input_freq' },
  { code => 'substr($raw_status_line, 33,2)',                name => 'Temperature',      key => 'temp' },
  { code => 'sprintf("%d", substr($raw_status_line, 29,3))', name => 'Battery Capacity', key => 'battery_capacity' },
  { code => 'substr($raw_status_line, 38,1)',                name => 'Utility',          key => 'utility' },
  { code => 'substr($raw_status_line, 39,1)',                name => 'Battery Low',      key => 'battery_low' },
  { code => 'substr($raw_status_line, 40,1)',                name => 'Bypass / AVR',     key => 'bypass_avr' },
  { code => 'substr($raw_status_line, 41,1)',                name => 'UPS Failed',       key => 'ups_failed' },
  { code => 'substr($raw_status_line, 42,1)',                name => 'On - OFF Line',    key => 'on_off_line' },
  { code => 'substr($raw_status_line, 43,1)',                name => 'Test',             key => 'test' },
  { code => 'substr($raw_status_line, 44,1)',                name => 'Shutdown Active',  key => 'shutdown_active' },
  { code => 'substr($raw_status_line, 45,1)',                name => 'Beeper',           key => 'beeper' },
);

use overload '""' => sub {
  my $self       = shift;
  my $ups_status = $self->get_status_line;
  return $self->error unless $ups_status;
  my $status_format = $self->status_format;
  my ($on, $off) = ($self->switch_on, $self->switch_off);
  my @format_keys;
  $status_format =~ s/(?<!%)%(\w+)/push(@format_keys,$1),'%s'/eg;
  sprintf "$status_format", map {
    (not exists $SWITCH_LIST{$_}) ? $ups_status->{$_} : (
       $ups_status->{$_} ? $on :  $off
    )
  } @format_keys;
};

sub new {
  my $class = shift;
  my %p     = @_;

  $errstr = undef;

  my $self = {};

  my $username      = $p{username}      || croak 'username not defined';
  my $password      = $p{password}      || croak 'password not defined';
  my $host          = $p{host}          || croak 'host not defined';
  my $port          = $p{port}          || $DEFAUL_UPS_WEB_SERVER_PORT;
  my $agent         = $p{user_agent}    || undef;
  my $proto         = $p{proto}         || 'http';
  my $status_format = $p{status_format} || $DEFAULT_FORMAT;
  my $sw_format     = $p{switch_format} || $DEFAULT_SWITCH_FORMAT;

  if ($sw_format =~ m[^(.+)/(.+)$]) {
    ($self->{switch_on}, $self->{switch_off}) = ($1, $2);
  } else {
    warn 'Wrong switch format, should be defined as [switch on str/switch off str]';
    ($self->{switch_on}, $self->{switch_off}) = (0, 1);
  }

  $self->{status_format} = $status_format;
  $self->{url}           = "$proto://$host:${port}$DEFAULT_UPS_PAGE";
  my $ua = LWP::UserAgent->new();
  $ua->agent($agent) if $agent;
  $ua->cookie_jar({});
  $self->{ua} = $ua;
  bless($self, $class)->_init($username, $password);
}

sub _init {
  my $self = shift;
  my ($login, $pass) = @_;
  my $req = HTTP::Request->new(GET => $self->url);
  $req->authorization_basic($login, $pass);
  $self->{req} = $req;
  unless ($self->_get_raw_status_line()) {
    $errstr = $self->error;
    return;
  }
  return $self;
}

# -----------------------------------------------------------------------
# $upsmon->_get_raw_status_line
# Raw ups status line: (216.0 000.0 216.0 033 50.0 0100 35.0 00001000
# Get raw ups status line from powercom upsmon pro web server via http
# Return scalar on success, undef overwise
# -----------------------------------------------------------------------
sub _get_raw_status_line {
  my $self     = shift;
  my $response = $self->ua->request($self->req);
  if ($response->is_success) {
    my $ups_status_line = $response->content;
    $ups_status_line =~ s/^\s+//;
    $ups_status_line =~ s/\s+$//;
    warn "Wrong status line [$ups_status_line] length ["
      . (length($ups_status_line))
      . "] should be [$RAW_STATUS_LENGTH]"
      if length($ups_status_line) != $RAW_STATUS_LENGTH;
    return $ups_status_line;
  } else {
    $self->{error} = "Cannot get [" . $self->url . "]: " . $response->status_line;
    return;
  }
}

sub get_status_line {
  my $self            = shift;
  my $raw_status_line = $self->_get_raw_status_line;
  return unless $raw_status_line;

  my %output;

  for (@UPS_STATUS_VOCUBLARY) {
    $output{ $_->{key} } = eval "$_->{code}";
  }

  return \%output;
}

1;

__END__

=pod

=head1 NAME

WWW::Powercom::Upsmonpro::Client - Interface to Powercom Upsmon Pro status web page

=head1 SYNOPSIS

  use v5.10;
  use strict;
  use Data::Dumper;

  my $upsmon = WWW::Powercom::Upsmonpro::Client->new(
    username => 'upsmon',
    password => 'upsmon',
    host     => 'upsmonprowebserver',
    port     => 8888
  ) or die $WWW::Powercom::Upsmonpro::Client::errstr;

  my $status = $upsmon->get_status_line;
  if ($status) {
    say Dumper $status;
  } else {
    say $upsmon->error;
  }

  # double quotes required
  say "$upsmon";

=head1 DESCRIPTION

WWW::Powercom::Upsmonpro::Client is interface library to POWERCOM UPSMON PRO web page.

POWERCOM UPSMON PRO is software produced by POWERCOM for POWERCOM UPS control and monitoring.
Copy of this software can be downloaded here L<http://www.pcm.ru/support/soft/>.
POWERCOM UPSMON PRO provide embedded web server with web page display's UPS status.
Web page gather data from server via ajax reqest and draw result.
This library does exactly the same, gather data from web server via http and translate the same way as web page does.

=head2 version note

=over

=item

This module have tested with UPSMON PRO 1.2

=item

There is nothing to do with Network UPS Tools upsmon

=back

=head1 METHODS

=head2 new

  my $upsmon = WWW::Powercom::Upsmonpro::Client->new(
    username => 'upsmon',
    password => 'upsmon',
    host     => 'upsmonprowebserver',
    port     => 8888
  )

Make object to access UPSMON PRO status

Return blessed ref on success, undef overwise

Caution: This make http request immediately after creation

=head3 Parmetrs

=over

=item username, password

UPSMON PRO Basic authorization credentials, required

=item host

web server host, required

=item port 

web server, optional, default 8000

=item status_format 

define what will be displayed at stringify object (like C<"$upsmon">), placeholders for status defined by '%' symbol and keyword (see example bellow)

=item switch_format 

define how switch will be displayed at stringify object, should be in format C<< <string for ON switch>/<string for OFF switch> >> (for example: C<ON/OFF, YES/NO, 1/0> )

=back

Availible keyword list and switches L</UPS status>

=head3 Default switch format

=over

=item status_format

C<Input Voltage: %input_voltage\n Output Voltage: %output_voltage\n Load: %load_level%%\n Temp: %temp\n Line: %on_off_line>

=item switch_format

C<On/Off>       

=back

 Will looking like:

  Input Voltage: 220 
  Output Voltage: 220 
  Load: 55% 
  Temp: 40 
  Line: On 

=head2 get_status_line
  
  my $ups_data = $upsmon->get_status_line or die $upsmon->error;
  print Dumper $ups_data;

  $VAR1 = {
    'beeper'           => '0',
    'temp'             => '36',
    'load_level'       => '31',
    'input_voltage'    => '218',
    'test'             => '0',
    'on_off_line'      => '1',
    'bypass_avr'       => '0',
    'input_freq'       => '50',
    'ups_failed'       => '0',
    'output_voltage'   => '218',
    'battery_capacity' => '100',
    'shutdown_active'  => '0',
    'utility'          => '0',
    'battery_low'      => '0'
  };

Get explained ups status

Return status hashref on success, undef overwise

=head1 UPS status

Spying from javascript code on upsmon pro web page(so its javascript substring here)

  name                      position           this script key       is flag?
  ----------------------------------------------------------------------------
  Input Voltage           - substring(1,4)   - %input_voltage
  Output Voltage          - substring(13,16) - %output_voltage
  Load Level              - substring(19,22) - %load_level
  Input Frequency         - substring(23,25) - %input_freq
  Temperature             - substring(33,35) - %temp
  Battery Capacity        - substring(29,32) - %battery_capacity
  Bit 7 : Utility         - substring(38,39) - %utility            - flag
  Bit 6 : Battery Low     - substring(39,40) - %battery_low        - flag
  Bit 5 : Bypass / AVR    - substring(40,41) - %bypass_avr         - flag
  Bit 4 : UPS Failed      - substring(41,42) - %ups_failed         - flag
  Bit 3 : On - OFF Line   - substring(42,43) - %on_off_line        - flag
  Bit 2 : Test            - substring(43,44) - %test               - flag
  Bit 1 : Shutdown Active - substring(44,45) - %shutdown_active    - flag
  Bit 0 : Beeper          - substring(45,46) - %beeper             - flag

=head1 AUTHOR

pru.mike <pru.mike@gmail.com>

=head1 LICENSE

This software is available under the same terms as perl.

=cut

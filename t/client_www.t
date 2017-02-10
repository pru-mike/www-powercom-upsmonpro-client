#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;
use Test::More;
use Test::Deep;
use Test::Mock::LWP;
use lib qw/lib/;
use WWW::Powercom::Upsmonpro::Client;

my $res_line   = '(220.0 000.0 220.0 032 50.0 0100 35.0 00001000';
my $res_status = {
  'shutdown_active'  => '0',
  'load_level'       => '32',
  'temp'             => '35',
  'output_voltage'   => '220',
  'ups_failed'       => '0',
  'input_freq'       => '50',
  'battery_capacity' => '100',
  'bypass_avr'       => '0',
  'test'             => '0',
  'input_voltage'    => '220',
  'utility'          => '0',
  'beeper'           => '0',
  'on_off_line'      => '1',
  'battery_low'      => '0'
};

$Mock_response->mock(content => sub { $res_line });
$Mock_ua->mock(cookie_jar => sub { });

my $upsmon = WWW::Powercom::Upsmonpro::Client->new(
  username => 'user',
  password => 'password',
  host     => '192.168.1.1',
  status_format =>
    "Input Voltage: %input_voltage\nOutput Voltage: %output_voltage\nLoad: %load_level%%\nTemp: %temp\nLine: %on_off_line\n",
  switch_format => 'Da/Net'
) or die $WWW::Powercom::Upsmonpro::Client::errstr;

is_deeply($Mock_request->new_args, [qw(HTTP::Request GET http://192.168.1.1:8000/ups.txt)], 'constructor params');

my $ups_status_line = $upsmon->_get_raw_status_line();

is($ups_status_line, $res_line, 'status line');

my $ups_status = $upsmon->get_status_line;

cmp_deeply($ups_status, $res_status, 'status decoding');

is("$upsmon", "Input Voltage: 220\nOutput Voltage: 220\nLoad: 32%\nTemp: 35\nLine: Da\n", 'format');

done_testing(4);


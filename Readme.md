# NAME

WWW::Powercom::Upsmonpro::Client - Interface to Powercom Upsmon Pro status web page

# SYNOPSIS

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

# DESCRIPTION

WWW::Powercom::Upsmonpro::Client is interface library to POWERCOM UPSMON PRO web page.

POWERCOM UPSMON PRO is software produced by POWERCOM for POWERCOM UPS control and monitoring.
Copy of this software can be downloaded here [http://www.pcm.ru/support/soft/](http://www.pcm.ru/support/soft/).
POWERCOM UPSMON PRO provide embedded web server with web page display's UPS status.
Web page gather data from server via ajax reqest and draw result.
This library does exactly the same, gather data from web server via http and translate the same way as web page does.

## version note

- This module have tested with UPSMON PRO 1.2
- There is nothing to do with Network UPS Tools upsmon

# METHODS

## new

    my $upsmon = WWW::Powercom::Upsmonpro::Client->new(
      username => 'upsmon',
      password => 'upsmon',
      host     => 'upsmonprowebserver',
      port     => 8888
    )

Make object to access UPSMON PRO status

Return blessed ref on success, undef overwise

Caution: This make http request immediately after creation

### Parmetrs

- username, password

    UPSMON PRO Basic authorization credentials, required

- host

    web server host, required

- port 

    web server, optional, default 8000

- status\_format 

    define what will be displayed at stringify object (like `"$upsmon"`), placeholders for status defined by '%' symbol and keyword (see example bellow)

- switch\_format 

    define how switch will be displayed at stringify object, should be in format `<string for ON switch>/<string for OFF switch>` (for example: `ON/OFF, YES/NO, 1/0` )

Availible keyword list and switches ["UPS status"](#ups-status)

### Default switch format

- status\_format

    `Input Voltage: %input_voltage\n Output Voltage: %output_voltage\n Load: %load_level%%\n Temp: %temp\n Line: %on_off_line`

- switch\_format

    `On/Off`       

    Will looking like:

     Input Voltage: 220 
     Output Voltage: 220 
     Load: 55% 
     Temp: 40 
     Line: On 

## get\_status\_line

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

# UPS status

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

# AUTHOR

pru.mike <pru.mike@gmail.com>

# LICENSE

This software is available under the same terms as perl.

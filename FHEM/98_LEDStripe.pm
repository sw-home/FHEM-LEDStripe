=head1
        98_LEDStripe.pm

# $Id: $

        Version 0.1

=head1 SYNOPSIS
        FHEM Module and firmware for controlling WS2812b LED stripes
        contributed by Stefan Willmeroth 2016

=head1 DESCRIPTION
        98_LEDStripe.pm is a perl module and should be copied into the FHEM directory

=head1 AUTHOR - Stefan Willmeroth
        swi@willmeroth.com (forum.fhem.de)
=cut

##############################################
package main;

use strict;
use warnings;
use HTTP::Request;
use LWP::UserAgent;
use Switch;
use Color;
require 'HttpUtils.pm';

my @gets = ('led_count','leds_on','rgb');

##############################################
sub LEDStripe_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "LEDStripe_Set";
  $hash->{DefFn}     = "LEDStripe_Define";
  $hash->{GetFn}     = "LEDStripe_Get";
  $hash->{AttrList}  = "remote_ip remote_port playfile playtimer power_switch repeat";
}

###################################
sub LEDStripe_Set($@)
{
  my ($hash, @a) = @_;
  my $rc = undef;
  my $reDOUBLE = '^(\\d+\\.?\\d{0,2})$';
  my $remote_ip = $hash->{remote_ip};
  my $remote_port = $hash->{remote_port};
  my $URL = "http://" . $remote_ip . (defined $remote_port?":".$remote_port:"");

  return "no set value specified" if(int(@a) < 2);
  return "on off pixel range pixels fire rainbow rgb:colorpicker,RGB" if($a[1] eq "?");

  shift @a;
  my $command = shift @a;

  Log 4, "LEDStripe command: $command";

  if($command eq "on")
  {
    my $playfile = AttrVal($hash->{NAME}, "playfile", undef);
    Log 4, "command on, file: " . $playfile;
    return "playfile attribute is not set" if (!defined($playfile));
    LEDStripe_power($hash,$command);
    $URL .= "/off";
    LEDStripe_request($hash,$URL);
    undef $hash->{playindex};
    LEDStripe_Timer($hash);
  }
  if($command eq "off")
  {
    LEDStripe_closeplayfile($hash);
    $URL .= "/off";
    LEDStripe_request($hash,$URL);
    LEDStripe_power($hash,$command);
  }
  if($command eq "fire")
  {
    LEDStripe_closeplayfile($hash);
    LEDStripe_power($hash,"on");
    $URL .= "/fire";
    LEDStripe_request($hash,$URL);
  }
  if($command eq "rainbow")
  {
    LEDStripe_closeplayfile($hash);
    LEDStripe_power($hash,"on");
    $URL .= "/rainbow";
    LEDStripe_request($hash,$URL);
  }
  if($command eq "pixel")
  {
    return "Set pixel needs four parameters: <desired_led> <red> <green> <blue>" if ( @a != 4 );
    my $desired_led=$a[0];
    $desired_led=($desired_led=~ m/$reDOUBLE/) ? $1:undef;
    return "desired_led value ".$a[0]." is not a valid number" if (!defined($desired_led));

    my $red=$a[1];
    $red=($red=~ m/$reDOUBLE/) ? $1:undef;
    return "red value ".$a[1]." is not a valid number" if (!defined($red));

    my $green=$a[2];
    $green=($green=~ m/$reDOUBLE/) ? $1:undef;
    return "green value ".$a[2]." is not a valid number" if (!defined($green));

    my $blue=$a[3];
    $blue=($blue=~ m/$reDOUBLE/) ? $1:undef;
    return "blue value ".$a[3]." is not a valid number" if (!defined($blue));

    LEDStripe_closeplayfile($hash);
    LEDStripe_power($hash,"on");

    Log 4, "set command: " . $command ." desired:". $desired_led;
    $URL .= "/rgb/" . $desired_led . "/" . $red . "," . $green . "," . $blue;
    LEDStripe_request($hash,$URL);
  }
  if($command eq "range")
  {
    return "Set range needs five parameters: <first_led> <last_led> <red> <green> <blue>" if ( @a != 5 );
    my $first_led=$a[0];
    $first_led=($first_led=~ m/$reDOUBLE/) ? $1:undef;
    return "first_led value ".$a[0]." is not a valid number" if (!defined($first_led));

    my $last_led=$a[1];
    $last_led=($last_led=~ m/$reDOUBLE/) ? $1:undef;
    return "last_led value ".$a[1]." is not a valid number" if (!defined($last_led));

    my $red=$a[2];
    $red=($red=~ m/$reDOUBLE/) ? $1:undef;
    return "red value ".$a[2]." is not a valid number" if (!defined($red));

    my $green=$a[3];
    $green=($green=~ m/$reDOUBLE/) ? $1:undef;
    return "green value ".$a[3]." is not a valid number" if (!defined($green));

    my $blue=$a[4];
    $blue=($blue=~ m/$reDOUBLE/) ? $1:undef;
    return "blue value ".$a[4]." is not a valid number" if (!defined($blue));

    LEDStripe_closeplayfile($hash);
    LEDStripe_power($hash,"on");

    Log 4, "set command: " . $command ." desired:". $first_led . " to " . $last_led;
    $URL .= "/range/" . $first_led . "," . $last_led . "/" . $red . "," . $green . "," . $blue;
    LEDStripe_request($hash,$URL);
  }
  if($command eq "rgb")
  {
    return "Set rgb needs a color parameter: <red><green><blue> e.g. ffaa00" if ( @a != 1 || length($a[0]) != 6);
    my $red=oct("0x".substr($a[0],0,2));
    my $green=oct("0x".substr($a[0],2,2));
    my $blue=oct("0x".substr($a[0],4,2));
    my $last_led=$hash->{READINGS}{led_count}{VAL} - 1;
    LEDStripe_closeplayfile($hash);
    LEDStripe_power($hash,"on");
    $URL .= "/range/0,$last_led/$red,$green,$blue";
    LEDStripe_request($hash,$URL);
    readingsSingleUpdate($hash, "rgb", $a[0], 1);
  }
  if($command eq "pixels")
  {
    return "Set pixels needs a parameter: <pixel_data>" if ( @a != 1 );
    my $pixels=$a[0];
    LEDStripe_closeplayfile($hash);
    LEDStripe_power($hash,"on");
    Log 4, "set command: " . $command ." with data:". $pixels;
    $URL .= "/leds/";
    LEDStripe_postrequest($hash,$URL,$pixels);
  }
  return undef;
}

#####################################
sub LEDStripe_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  my $u = "wrong syntax: define <name> LEDStripe <ip-address>";
  return $u if(int(@a) != 3);

  $hash->{remote_ip} = $a[2];

  my $URL = "http://" . $hash->{remote_ip} . (defined $hash->{remote_port}?":".$hash->{remote_port}:"") . "/status";

  LEDStripe_request($hash,$URL);

  Log 2, "$hash->{NAME} defined LEDStripe at $hash->{remote_ip}:$hash->{remote_port} ";

  return undef;
}

#####################################
sub LEDStripe_Undef($$)
{
   my ( $hash, $arg ) = @_;

   LEDStripe_closeplayfile($hash);
   Log 3, "--- removed ---";
   return undef;
}

#####################################
sub LEDStripe_Get($@)
{
  my ($hash, @args) = @_;

  return 'LEDStripe_Get needs two arguments' if (@args != 2);

  my $get = $args[1];
  my $val = $hash->{Invalid};
  
  if (defined($hash->{READINGS}{$get})) {
    $val = $hash->{READINGS}{$get}{VAL};
  } else {
    return "LEDStripe_Get: no such reading: $get";
  }

  Log 3, "$args[0] $get => $val";

  return $val;
}

#####################################
sub LEDStripe_Timer
{
  my ($hash) = @_;
  my $name   = $hash->{NAME};
  my $room_id = $hash->{room_id};
  my $remote_ip = $hash->{remote_ip};
  my $remote_port = $hash->{remote_port};
  my $playindex = (defined $hash->{playindex}?$hash->{playindex}:1);
  my $fh = $hash->{filehash};
  my $playfile = AttrVal($name, "playfile", undef);
  my $playtimer = AttrVal($name, "playtimer", 2);
  my $URL = "http://" . $remote_ip . (defined $remote_port?":".$remote_port:"") . "/leds/";

  my $count=1;
  my $firstline;

  if (!defined($fh)) {
    if (!open($fh, '<:encoding(UTF-8)', $playfile)) {
      Log 1, "Could not open file $playfile";
      return;
    }
    $hash->{filehash} = $fh;
    while (my $row = <$fh>) {
      chomp $row;
      if ($count == 1) {
        $firstline = $row;
      }
      if ($count++ == $playindex) {
        $firstline = $row;
        last;
      }
    }

    if ($count == $playindex) {
      $playindex = 2;
    } else {
      $playindex++;
    }

  } else {
    if (!($firstline = <$fh>)) {
      if (AttrVal($hash->{NAME}, "repeat", 0) == 1) {
        seek ($fh,0,SEEK_SET);
        $firstline = <$fh>;
        $playindex=2;
      } else {
        LEDStripe_closeplayfile();
        if ($hash->{STATE} eq "off") {
          LEDStripe_power($hash, "off");
        }
        return;
      }
    } else {
      $playindex++;
    }
  }
  $hash->{playindex} = $playindex;

  LEDStripe_postrequest($hash,$URL,$firstline);

  InternalTimer( gettimeofday() + $playtimer, "LEDStripe_Timer", $hash, 0);
}

#####################################
sub LEDStripe_power
{
  my ($hash, $command) = @_;
  my $name   = $hash->{NAME};
  my $switch = AttrVal($name, "power_switch", undef);
  if (defined $switch) {
    my $currentpower = Value($switch);
    if($command ne $currentpower) {
      fhem "set $switch $command";
      if ($command eq "on") {
        select(undef, undef, undef, 1.5);
      }
    }
  }
}

#####################################
sub LEDStripe_closeplayfile
{
  my ($hash) = @_;
  RemoveInternalTimer($hash) if $hash->{playindex};
  if (defined($hash->{filehash})) {
    close ($hash->{filehash});
    $hash->{filehash} = undef;
  }
}

#####################################
sub LEDStripe_request
{
  my ($hash, $URL) = @_;
  my %readings = ();

  Log 4, "LEDStripe request: $URL";

  my $agent = LWP::UserAgent->new( env_proxy => 1, keep_alive => 1, timeout => 3 );
  my $header = HTTP::Request->new( GET => $URL );
  my $request = HTTP::Request->new( 'GET', $URL, $header );
  my $response = $agent->request($request);

  if (!$response->is_success)
  {
    my $err_log = "Can't get $URL -- " . $response->status_line;
    Log 1, $err_log;
    $hash->{STATE} = "FAIL";
    return $err_log;
  }

  my $result = $response->content;

  $result =~ s/^\s+|\s+$//g;

  Log 4, "LEDStripe response: " . $result;

  readingsBeginUpdate($hash);

  my @a = split( /,/, $result);

  $readings{led_count} = $a[1];
  $readings{leds_on} = $a[2];

  $hash->{STATE} = ($readings{leds_on} > 0) ? "on":"off";
  $readings{state} = $hash->{STATE};

  # update Readings
  for my $get (@gets) {
    readingsBulkUpdate($hash, $get, $readings{$get});
  }

  readingsEndUpdate($hash, $init_done);

  return "LEDStripe returned " . $result . ", new state is ". $hash->{STATE};
}

#####################################
sub LEDStripe_postrequest
{
  my ($hash, $URL, $post_data) = @_;
  my %readings = ();

  Log 4, "LEDStripe POST request: $URL";

  my $agent = LWP::UserAgent->new( env_proxy => 1, keep_alive => 1, timeout => 3 );
  my $header = HTTP::Request->new( POST => $URL );
  my $request = HTTP::Request->new( 'POST', $URL, $header );
  # add POST data to HTTP request body
  # my $post_data = '{ "name": "Dan", "address": "NY" }';
  $request->content($post_data);

  my $response = $agent->request($request);

  if (!$response->is_success)
  {
    my $err_log = "Can't post to $URL -- " . $response->status_line;
    Log 1, $err_log;
    return $err_log;
  }

  my $result = $response->content;

  $result =~ s/^\s+|\s+$//g;

  Log 4, "LEDStripe response: " . $result;

  readingsBeginUpdate($hash);

  my @a = split( /,/, $result);

  $readings{led_count} = $a[1];
  $readings{leds_on} = $a[2];

  $hash->{STATE} = ($readings{leds_on} > 0) ? "on":"off";
  $readings{state} = $hash->{STATE};

  # update Readings
  for my $get (@gets) {
    readingsBulkUpdate($hash, $get, $readings{$get});
  }

  readingsEndUpdate($hash, $init_done);

  return "LEDStripe returned " . $result . ", new state is ". $hash->{STATE};
}

1;

=pod
=begin html

<html>
<a name="LEDStripe"></a>
<h3>LEDStripe</h3>
<ul>
  <a name="LEDStripe_define"></a>
  <h4>Define</h4>
  <ul>
    <code>define &lt;name&gt; LEDStripe &lt;ip_address&gt;</code>
    <br/>
    <br/>
    Defines a module for controlling WS2812b LED stripes connected to an Arduino with Ethernet shield or an ESP8266 <br/><br/>
    Example:
    <ul>
      <code>define LED_Wohnzimmer LEDStripe 192.168.1.21</code><br>
      <code>attr LED_Wohnzimmer playfile /opt/fhem/ledwall.txt</code><br>
      <code>attr LED_Wohnzimmer webCmd rgb:off:rgb 5a2000:rgb 654D8A</code><br>
      <code>attr LED_Wohnzimmer power_switch RL23_LED_WZ</code><br>
    </ul>

  </ul>

  <a name="LEDStripe_Attr"></a>
  <h4>Attributes</h4>
  <ul>
    <li><a name="playfile"><code>attr &lt;name&gt; playfile &lt;string&gt;</code></a>
                <br />Points to a file with LED color information containing several lines in the pixels format described below</li>
    <li><a name="playtimer"><code>attr &lt;name&gt; playtimer &lt;integer&gt;</code></a>
                <br />Delay in seconds when playing a LED color file</li>
    <li><a name="webCmd"><code>attr &lt;name&gt; webCmd rgb:off:rgb 5a2000:rgb 654D8A</code></a>
                <br />Show a color picker and color buttons (the colors are just examples, any combinations are possible)./li>
    <li><a name="power_switch"><code>attr &lt;name&gt; power_switch &lt;integer&gt;</code></a>
                <br />Control LED power on/off using s switch channel</li>
    <li><a name="repeat"><code>attr &lt;name&gt; repeat &lt;integer&gt;</code></a>
                <br />Set to 1 to repeat the play file animation until the device is set to off</li>
  </ul>

  <a name="LEDStripe_set"></a>
  <b>Set</b>
  <ul>
    <li><a name="on"><code>set &lt;name&gt; on</code></a>
                <br />Start 'playing' the file with LED color information</li>
    <li><a name="off"><code>set &lt;name&gt; off</code></a>
                <br />Switch all LEDs off and stop any effects</li>
    <li><a name="pixel"><code>set &lt;name&gt; pixel &lt;led id&gt; &lt;red&gt; &lt;green&gt; &lt;blue&gt;</code></a>
                <br />Set the color of a single LED, index starts at 0, color values are from 0-255</li>
    <li><a name="range"><code>set &lt;name&gt; range &lt;start id&gt; &lt;end id&gt; &lt;red&gt; &lt;green&gt; &lt;blue&gt;</code></a>
                <br />Set the color of a range of LEDs, start and end are inclusive beginning with 0</li>
    <li><a name="pixels"><code>set &lt;name&gt; pixels &lt;color data&gt;</code></a>
                <br />Define the color of all LEDs, the color data consists of three hex digits per LED containing the three colors,
                e.g. 000 would be off, F00 would be all red, 080 would be 50% green, 001 a faint blue</li>
    <li><a name="fire"><code>set &lt;name&gt; fire</code></a>
                <br />Start a 'fire' light effect on all LEDs</li>
    <li><a name="rainbow"><code>set &lt;name&gt; rainbow &lt;string&gt;</code></a>
                <br />Start a 'rainbow color chase' light effect on all LEDs</li>
  </ul>

</ul>

=end html
=cut

#! /usr/bin/perl

use strict;
use Time::HiRes qw(usleep);
use Carp;
use IO::File;

require "linux/i2c-dev.ph";

my $i2c_bus = 1;
my $i2c_dev_id = 0x40; # use i2cdiscover -y 1 to find
my $i2c_dev_file = sprintf "/dev/i2c-%d", $i2c_bus;

my $i2c_dev = IO::File->new( $i2c_dev_file, O_RDWR, 0 );

die "open($i2c_dev_file): $!\n"
    unless $i2c_dev;

$i2c_dev->ioctl(I2C_SLAVE(), $i2c_dev_id)
    or die "ioctl: $!\n";

my($t,$h) = shtread($i2c_dev);

printf "%s %s %s\n", time, $t, $h;

exit 0;

sub i2c_write {
    my($dev,$template,@data) = @_;
    my $data = pack $template, @data;
    $dev->syswrite($data, length $data)
	or croak "write: $!\n";
}

sub crc_chk {
    my($data) = @_;
    my $crc = 0;
    my @bytes = unpack "C*", $data;
    my $data_crc = pop @bytes;
    for my $byte (@bytes) {
	$crc ^= $byte;
	for (0..7) {
	    if ($crc & 0x80) {
		$crc = ($crc << 1) ^ 0x131;
	    }
	    else {
		$crc <<= 1;
	    }
	}
	$crc &= 0xff;
    }
    return $data_crc == $crc;
}

sub shtread {
    my($dev) = @_;
    my $buf;

    # soft reset
    i2c_write($dev, "C", 0xfe);
    usleep(50_000);

    # start temp read
    i2c_write($dev, "C", 0xf3);
    usleep(86_000);

    # Read temp data (14 bit data, 2 padding, 8 crc)
    my $temp = 'NA';
    $dev->sysread($buf, 3);
    if (crc_chk($buf)) {
	$temp = unpack "n", $buf;
	$temp &= 0xfffc;
	$temp *= 175.72;
	$temp /= 2**16;
	$temp -= 46.85;
    }
    else {
	$temp = 'RE';
    }

    # start humidity read
    i2c_write($dev, "C", 0xf5);
    usleep(30_000);
    
    # read humidity (12 bit data, 4 padding, 8 crc)
    my($humidity) = 'NA';
    
    $dev->sysread($buf, 3);
    if (crc_chk($buf)) {
	$humidity = unpack "n", $buf;
	$humidity *= 125;
	$humidity /= 2**16;
	$humidity -= 6;
    }
    else {
	$humidity = 'RE';
    }
    
    return ($temp, $humidity);
}

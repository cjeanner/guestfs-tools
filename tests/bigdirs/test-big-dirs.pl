#!/usr/bin/perl
# Copyright (C) 2012 Red Hat Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Test long directories and protocol limits.

use strict;
use warnings;

use Sys::Guestfs;

# Skip this test on 32 bit machines, since we cannot create a large
# enough file below.
if (~1 == 4294967294) {
    print STDERR "$0: tested skipped because this is a 32 bit machine\n";
    exit 77
}

my $g = Sys::Guestfs->new ();

# Create a 16 GB test file.  Don't worry, it's sparse.
#
# It has to be this big because the 'defaults' configuration of mke2fs
# will choose a default inode ratio of 16K, and in order to create a
# million files that means we have to have the disk be >= 16K * 1000000
# bytes in size.
my $nr_files = 1000000;
my $image_size = 16*1024*1024*1024;

unlink "test.img";
open FILE, ">test.img" or die "test.img: $!";
truncate FILE, $image_size or die "test.img: truncate: $!";
close FILE or die "test.img: $!";

$g->add_drive ("test.img", format => "raw");

$g->launch ();

$g->part_disk ("/dev/sda", "mbr");
$g->mkfs ("ext4", "/dev/sda1");
$g->mount ("/dev/sda1", "/");

my %df = $g->statvfs ("/");
die "$0: internal error: not enough inodes on filesystem"
    unless $df{favail} > $nr_files;

# Create a very large directory.  The aim is that the number of files
# * length of each filename should be longer than a protocol message
# (currently 4 MB).
$g->mkdir ("/dir");
$g->fill_dir ("/dir", $nr_files);

# Listing the directory should be OK.
my @filenames = $g->ls ("/dir");

# Check the names (they should be sorted).
die "incorrect number of filenames returned by \$g->ls"
    unless @filenames == $nr_files;
for (my $i = 0; $i < $nr_files; ++$i) {
    if ($filenames[$i] ne sprintf ("%08d", $i)) {
        die "unexpected filename at index $i: $filenames[$i]";
    }
}

# Check that lstatlist, lxattrlist and readlinklist return the
# expected number of entries.
my @a;
@filenames = map { "/dir/$_" } @filenames;

@a = $g->lstatlist ("/dir", \@filenames);
die unless @a == $nr_files;
@a = $g->lxattrlist ("/dir", \@filenames);
die unless @a == $nr_files;
@a = $g->readlinklist ("/dir", \@filenames);
die unless @a == $nr_files;

$g->shutdown ();
$g->close ();

unlink "test.img"

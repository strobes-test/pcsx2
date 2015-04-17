#!/usr/bin/perl

# PCSX2 - PS2 Emulator for PCs
# Copyright (C) 2002-2014  PCSX2 Dev Team
#
# PCSX2 is free software: you can redistribute it and/or modify it under the terms
# of the GNU Lesser General Public License as published by the Free Software Found-
# ation, either version 3 of the License, or (at your option) any later version.
#
# PCSX2 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with PCSX2.
# If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use File::Spec;
use File::Basename;
use File::Copy;
use Cwd 'abs_path';

# Allow to use the script without the module. I don't want a full PERL as a dependency of PCSX2!
my $g_disable_md5 = 0;
eval {
    require Digest::file;
    require Digest::MD5;
    Digest::file->import(qw/digest_file_hex/);
    Digest::MD5->import(qw/md5_hex/);
    1;
} or do {
    $g_disable_md5 = 1;
    print "Disable MD5\n";
};

########################
# GSdx
########################
my @gsdx_res = qw/convert.glsl interlace.glsl merge.glsl shadeboost.glsl tfx_vgs.glsl tfx_fs_all.glsl fxaa.fx/;
my $gsdx_path = File::Spec->catdir(dirname(abs_path($0)), "..", "plugins", "GSdx", "res");
# Just a hack to reuse glsl2h function easily
my @tfx_res = qw/tfx_fs.glsl tfx_fs_subroutine.glsl/;
my $tfx_all = File::Spec->catdir($gsdx_path, "tfx_fs_all.glsl");
concat($gsdx_path, $tfx_all, \@tfx_res);

my $gsdx_out = File::Spec->catdir($gsdx_path, "glsl_source.h");
glsl2h($gsdx_path, $gsdx_out, \@gsdx_res);

unlink $tfx_all;

########################
# ZZOGL
########################
my @zz_res  = qw/ps2hw_gl4.glsl/;
my $zz_path = File::Spec->catdir(dirname(abs_path($0)), "..", "plugins", "zzogl-pg", "opengl");
my $zz_out = File::Spec->catdir($zz_path, "ps2hw_gl4.h");
glsl2h($zz_path, $zz_out, \@zz_res);

sub concat {
    my $in_dir = shift;
    my $out_file = shift;
    my $glsl_files = shift;

    my $line;
    open(my $TMP, ">$out_file");
    foreach my $file (@{$glsl_files}) {
        open(my $GLSL, File::Spec->catfile($in_dir, $file)) or die "$! : $file";
        while(defined($line = <$GLSL>)) {
            print $TMP $line;
        }
    }

}

sub glsl2h {
    my $in_dir = shift;
    my $out_file = shift;
    my $glsl_files = shift;

    my $include = "";
    if ($in_dir =~ /GSdx/) {
        $include = "#include \"stdafx.h\""
    }

    my $header = <<EOS;
/*
 *  This file was generated by glsl2h.pl script
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA USA.
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#pragma once

$include
EOS

    my $data = $header;

    foreach my $file (@{$glsl_files}) {
        my $name = $file;
        $name =~ s/\./_/;
        $data .= "\nstatic const char* $name =\n";

        open(my $GLSL, File::Spec->catfile($in_dir, $file)) or die "$! : $file";
        my $line;
        while(defined($line = <$GLSL>)) {
            chomp $line;
            $line =~ s/\\/\\\\/g;
            $line =~ s/"/\\"/g;
            $data .= "\t\"$line\\n\"\n";
        }
        $data .= "\t;\n";
    }

    # Rewriting the file will trigger a relink (even if the content is the
    # same). So we check first the content with md5 digest
    if ( -e $out_file and not $g_disable_md5) {
        my $old_md5 = digest_file_hex($out_file, "MD5");
        my $new_md5 = md5_hex($data);

        if ($old_md5 ne $new_md5) {
            open(my $H, ">$out_file") or die;
            print $H $data;
        }
    } else {
        open(my $H, ">$out_file") or die;
        print $H $data;
    }
}

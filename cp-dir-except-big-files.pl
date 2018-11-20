#!/usr/bin/env perl
# EPN, Fri Nov 16 06:01:10 2018
# cp-dir-except-big-files.pl
# Copy all files from a directory to the current directory except files above 
# a certain size
use warnings;
use strict;
use Getopt::Long;

my $usage;
$usage  = "perl cp-dir-except-big-files.pl <source dir> <dest dir (can be '.')> <maximum file size in Gb>\n";

$usage .= "\tOPTIONS:\n";
$usage .= "\t\t-d: just print cp and mkdir commands, don't actually execute them\n";
$usage .= "\t\t-v: print commands as they're run\n";

my $do_dry     = 0;
my $do_verbose = 0;
&GetOptions( "d" => \$do_dry,
             "v" => \$do_verbose);

if($do_dry && $do_verbose) { die "ERROR -d and -v are incompatible, pick one."; }

if(scalar(@ARGV) != 3) { die $usage; }
my ($src_dir, $dst_dir, $gb_limit) = (@ARGV);

# do the full job with one call, that may call itself recursively
if($dst_dir ne ".") { 
  run_command("mkdir $dst_dir", $do_dry, $do_verbose);
}
actually_cp_dir_except_big_files($src_dir, $dst_dir, $gb_limit, $do_dry, $do_verbose);

#################################################################
# Subroutine:  actually_cp_dir_except_big_files()
# Incept:      EPN, Fri Nov 16 06:18:32 2018
#
# Purpose:     Actually do the work for this script, needed as 
#              a subroutine so we can call it recursively for 
#              subdirectories. Copies all files and subdirectories
#              from $src_dir to $dst_dir except those files that
#              exceed $gb_limit in Gb.
#
# Arguments:
#   $src_dir:    source directory, to copy from
#   $dst_dir:    destination directory, to copy to
#   $gb_limit:   maximum file size to copy, in Gb
#   $do_dry:     only print commands, don't execute them
#   $do_verbose: print and execute commands
#
# Returns:    void
#
# Dies:       if a command to copy fails
#################################################################
sub actually_cp_dir_except_big_files { 
  my $sub_name = "actually_cp_dir_except_big_files";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($src_dir, $dst_dir, $gb_limit, $do_dry, $do_verbose) = @_;

  my $ls_ltr_out = `ls -ltr $src_dir | grep -v ^total`;
  my @ls_ltr_out_A = split("\n", $ls_ltr_out);
  foreach my $ls_ltr_line (@ls_ltr_out_A) { 
    my @el_A = split(/\s+/, $ls_ltr_line);
    if(scalar(@el_A) != 9) { die "ERROR didn't read 9 tokens on ls -ltr line: $ls_ltr_line"; }
    my ($permissions, $size, $filename) = ($el_A[0], $el_A[4], $el_A[8]);
    my $gb_size = $size / 1000000000;
    my $is_dir = ($permissions =~ m/^d/) ? 1 : 0;
    my $src_file = $src_dir . "/" . $filename;
    my $dst_file = $dst_dir . "/" . $filename;
    
    if($is_dir) { 
      my $new_src_dir = $src_file;
      my $new_dst_dir = $dst_file;
      run_command("mkdir $new_dst_dir", $do_dry, $do_verbose);
      # recursive call for subdir
      actually_cp_dir_except_big_files($new_src_dir, $new_dst_dir, $gb_limit, $do_dry, $do_verbose);
    }
    elsif($gb_size < $gb_limit) { 
      run_command("cp $src_file $dst_file", $do_dry, $do_verbose);
    }
    else { 
      printf("Not copying %-40s (%.2f > %.2f)\n", $src_file, $gb_size, $gb_limit);
    }
  }
  return;
}
                                 
#################################################################
# Subroutine:  run_command()
# Incept:      EPN, Fri Nov 16 06:23:53 2018
#
# Purpose:     Runs a command using system() and exits in error 
#              if the command fails.
#
# Arguments:
#   $cmd:        command to run, with a "system" command;
#   $do_dry:     only print commands, don't execute them
#   $do_verbose: print and execute commands
#
# Returns:    void
#
# Dies:       if $cmd fails
#################################################################
sub run_command {
  my $sub_name = "run_command()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($cmd, $do_dry, $do_verbose) = @_;
  
  if($do_dry || $do_verbose) { 
    print("$cmd\n"); 
  }
  if(! $do_dry) { 
    system($cmd);
    if($? != 0) { die "ERROR, the following command failed:\n$cmd\n"; }
  }

  return;
}

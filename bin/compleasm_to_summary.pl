#!/usr/bin/perl
use strict;
use Getopt::Long;
use File::Basename;

my $usage = <<USAGE;
Usage:
    perl $0 compleasm_output_dir/

    This script parses compleasm output and formats it as a BUSCO-style summary line.
    It reads the summary.txt file from the compleasm output directory.

    Output format:
    C:95.2%[S:90.1%,D:5.1%],F:2.3%,M:2.5%,n:1614

    --help    Display this help and exit

USAGE
if (@ARGV == 0) { die $usage }

my $help;
GetOptions(
    "help" => \$help,
);
if ($help) { die $usage }

my $output_dir = $ARGV[0];
$output_dir =~ s/\/+$//;

# compleasm produces a summary.txt file in its output directory
# Look for summary.txt or summary file
my $summary_file;
if (-e "$output_dir/summary.txt") {
    $summary_file = "$output_dir/summary.txt";
}
elsif (-e "$output_dir/miniprot_output.txt") {
    $summary_file = "$output_dir/miniprot_output.txt";
}
else {
    # Try to find any summary-like file
    opendir(my $dh, $output_dir) or die "Error: cannot open directory $output_dir: $!\n";
    my @files = readdir($dh);
    closedir($dh);
    foreach my $f (@files) {
        if ($f =~ /summary/i && -f "$output_dir/$f") {
            $summary_file = "$output_dir/$f";
            last;
        }
    }
    die "Error: cannot find summary file in $output_dir\n" unless $summary_file;
}

# Parse compleasm summary.txt
# Expected format from compleasm:
# S:90.1%, 1455
# D:5.1%, 82
# F:2.3%, 37
# I:0.0%, 0
# M:2.5%, 40
# N:1614
#
# Alternatively, compleasm may produce lines like:
# Complete: 95.2% (S: 90.1%, D: 5.1%)
# Fragmented: 2.3%
# Missing: 2.5%
# Total: 1614

open my $fh, '<', $summary_file or die "Error: cannot open $summary_file: $!\n";

my ($single, $duplicated, $fragmented, $missing, $total);
my ($complete);

while (<$fh>) {
    chomp;
    s/^\s+//;
    s/\s+$//;

    # Format 1: "S:90.1%, 1455" style
    if (/^S:\s*([\d.]+)%/) {
        $single = $1;
    }
    elsif (/^D:\s*([\d.]+)%/) {
        $duplicated = $1;
    }
    elsif (/^F:\s*([\d.]+)%/) {
        $fragmented = $1;
    }
    elsif (/^M:\s*([\d.]+)%/) {
        $missing = $1;
    }
    elsif (/^N:\s*(\d+)/) {
        $total = $1;
    }
    # Format 2: "Complete: 95.2% (S: 90.1%, D: 5.1%)" style
    elsif (/^Complete.*?(\d+\.\d+)%.*S.*?(\d+\.\d+)%.*D.*?(\d+\.\d+)%/) {
        $complete = $1;
        $single = $2;
        $duplicated = $3;
    }
    elsif (/^Fragmented.*?(\d+\.\d+)%/) {
        $fragmented = $1;
    }
    elsif (/^Missing.*?(\d+\.\d+)%/) {
        $missing = $1;
    }
    elsif (/^Total.*?(\d+)/) {
        $total = $1;
    }
    # Format 3: "I:" line (intact/complete single-copy in some compleasm versions)
    elsif (/^I:\s*([\d.]+)%/) {
        # Some compleasm versions use I for intact; skip or treat as additional info
    }
}
close $fh;

# Calculate complete if we have single and duplicated
unless (defined $complete) {
    if (defined $single && defined $duplicated) {
        $complete = sprintf("%.1f", $single + $duplicated);
    }
}

# Validate that we have all required values
unless (defined $complete && defined $single && defined $duplicated &&
        defined $fragmented && defined $missing && defined $total) {
    die "Error: could not parse all required fields from $summary_file\n" .
        "  Complete=$complete, Single=$single, Duplicated=$duplicated, " .
        "Fragmented=$fragmented, Missing=$missing, Total=$total\n";
}

# Output in BUSCO summary format
print "C:${complete}%[S:${single}%,D:${duplicated}%],F:${fragmented}%,M:${missing}%,n:${total}\n";

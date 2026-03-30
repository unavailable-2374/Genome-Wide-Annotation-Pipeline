#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Cwd qw/abs_path getcwd cwd/;
use File::Basename;

my $bin_path = dirname($0);

my $usage = <<USAGE;
Usage:
    $0 [options] genome.fasta protein.fasta miniprot_raw.gff > out.geneModels.gff3

    This program converts miniprot GFF3 output to GETA-compatible GFF3 format.
    It reads miniprot's raw GFF output (with mRNA, CDS, stop_codon features and ##PAF lines),
    parses alignment quality metrics (Identity, coverage from Target), groups overlapping
    alignments into gene loci, picks the best alignment per locus, classifies gene models
    into four categories (excellent/good/fair/poor), and outputs GETA-standard GFF3.

    It also generates:
    - An alignment GFF3 file (protein_match features) in the tmp_dir.
    - A raw prediction GFF3 file (all gene models before locus-level deduplication).

    --genetic_code <int>    default: 1
    Genetic code table number.

    --min_coverage <float>    default: 0.4
    Minimum protein coverage threshold for keeping a gene model (fair class).

    --min_identity <float>    default: 0.2
    Minimum identity threshold for keeping a gene model (fair class).

    --out_prefix <string>    default: out
    Output file prefix.

    --tmp_dir <string>    default: tmp_\$date\$pid
    Temporary directory.

    --help
    Display this help and exit.

USAGE
if (@ARGV==0){die $usage}

my ($genetic_code, $min_coverage, $min_identity, $out_prefix, $tmp_dir, $help);
GetOptions(
    "genetic_code:i" => \$genetic_code,
    "min_coverage:f" => \$min_coverage,
    "min_identity:f" => \$min_identity,
    "out_prefix:s" => \$out_prefix,
    "tmp_dir:s" => \$tmp_dir,
    "help" => \$help,
);
if ( $help ) { die $usage }

$genetic_code ||= 1;
$min_coverage ||= 0.4;
$min_identity ||= 0.2;
$out_prefix ||= "out";
my $date = `date +%Y%m%d%H%M%S`; chomp($date);
$tmp_dir ||= "tmp_$date$$";
$tmp_dir = abs_path($tmp_dir);
mkdir $tmp_dir unless -e $tmp_dir;

my $input_genome = abs_path($ARGV[0]);
my $input_protein = abs_path($ARGV[1]);
my $input_gff = abs_path($ARGV[2]);

# Read genome sequences for codon detection
print STDERR "Reading genome sequences...\n";
open IN, $input_genome or die "Can not open file $input_genome, $!";
my (%genome_seq, $seq_id);
while (<IN>) {
    chomp;
    if (/>(\S+)/) { $seq_id = $1; }
    else { $genome_seq{$seq_id} .= uc($_); }
}
close IN;

# Read protein sequences for length information
print STDERR "Reading protein sequences...\n";
open IN, $input_protein or die "Can not open file $input_protein, $!";
my (%protein_length, $prot_id);
while (<IN>) {
    chomp;
    if (/>(\S+)/) { $prot_id = $1; }
    else { $protein_length{$prot_id} += length($_); }
}
close IN;

# Get codon table
my ($codon_table_ref, $start_codon_ref, $stop_codon_ref) = &codon_table($genetic_code);
my %stop_codon = %$stop_codon_ref;
my %start_codon = %$start_codon_ref;

# Parse miniprot GFF output
# miniprot outputs: mRNA features with CDS children and optional stop_codon
# mRNA attributes: ID, Rank, Identity, Positive, Target, Frameshift, StopCodon
# CDS attributes: Parent, Rank, Target (protein coords for this exon), phase
# ##PAF lines contain detailed alignment info
print STDERR "Parsing miniprot GFF output...\n";
open IN, $input_gff or die "Can not open file $input_gff, $!";

my %mrna_data;      # mRNA_ID => { chr, start, end, strand, identity, positive, target_name, target_start, target_end, score, rank, frameshift, stopcodon, protein_length }
my %mrna_cds;       # mRNA_ID => [ [chr, start, end, strand, phase, target_start, target_end], ... ]
my %mrna_has_stop;  # mRNA_ID => 1 if stop_codon feature present
my @mrna_order;     # maintain input order
my %paf_data;       # mRNA_ID => PAF line data (AS score, etc.)

my $current_mRNA_id;
my %pending_paf;  # temporary storage for PAF data until next mRNA line arrives
while (<IN>) {
    chomp;
    next if /^$/;

    # Parse ##PAF lines for alignment score
    # In miniprot --gff output, ##PAF line comes BEFORE the mRNA line for each alignment
    if (/^##PAF\t/) {
        my @fields = split /\t/;
        # PAF format: ##PAF qname qlen qstart qend strand tname tlen tstart tend match_bases aln_bases mapq [tags]
        # Note: fields[0] is "##PAF", fields[1] is qname, etc.
        my $as_score = 0;
        my $ms_score = 0;
        foreach my $tag (@fields[13..$#fields]) {
            if ($tag =~ /^AS:i:(-?\d+)/) { $as_score = $1; }
            elsif ($tag =~ /^ms:i:(-?\d+)/) { $ms_score = $1; }
        }
        # Save temporarily; will be associated with the next mRNA line
        %pending_paf = (as_score => $as_score, ms_score => $ms_score);
        next;
    }

    next if /^#/;

    my @fields = split /\t/, $_, 9;
    next unless @fields >= 9;

    my ($chr, $source, $type, $start, $end, $score, $strand, $phase, $attr) = @fields;

    if ($type eq "mRNA") {
        # Parse attributes
        my %attrs;
        foreach my $kv (split /;/, $attr) {
            if ($kv =~ /^(\w+)=(.*)/) {
                $attrs{$1} = $2;
            }
        }
        my $mRNA_id = $attrs{ID} || "unknown_$$";
        $current_mRNA_id = $mRNA_id;

        # Associate pending PAF data with this mRNA
        if (%pending_paf) {
            $paf_data{$mRNA_id} = { %pending_paf };
            %pending_paf = ();
        }

        my ($target_name, $target_start, $target_end) = ("", 0, 0);
        if ($attrs{Target} && $attrs{Target} =~ /^(\S+)\s+(\d+)\s+(\d+)/) {
            $target_name = $1;
            $target_start = $2;  # 1-based from miniprot
            $target_end = $3;    # 1-based from miniprot
        }

        my $identity = $attrs{Identity} || 0;
        my $positive = $attrs{Positive} || 0;
        my $rank = $attrs{Rank} || 0;
        my $frameshift = $attrs{Frameshift} || 0;
        my $stopcodon_count = $attrs{StopCodon} || 0;
        $score = 0 if $score eq ".";

        my $prot_len = $protein_length{$target_name} || 0;

        $mrna_data{$mRNA_id} = {
            chr => $chr,
            start => $start,
            end => $end,
            strand => $strand,
            identity => $identity,
            positive => $positive,
            target_name => $target_name,
            target_start => $target_start,
            target_end => $target_end,
            score => $score,
            rank => $rank,
            frameshift => $frameshift,
            stopcodon_count => $stopcodon_count,
            protein_length => $prot_len,
        };
        $mrna_cds{$mRNA_id} = [];
        push @mrna_order, $mRNA_id;
    }
    elsif ($type eq "CDS") {
        my %attrs;
        foreach my $kv (split /;/, $attr) {
            if ($kv =~ /^(\w+)=(.*)/) {
                $attrs{$1} = $2;
            }
        }
        my $parent = $attrs{Parent} || $current_mRNA_id;

        my ($target_start, $target_end) = (0, 0);
        if ($attrs{Target} && $attrs{Target} =~ /^\S+\s+(\d+)\s+(\d+)/) {
            $target_start = $1;
            $target_end = $2;
        }

        if (exists $mrna_cds{$parent}) {
            push @{$mrna_cds{$parent}}, [$chr, $start, $end, $strand, $phase, $target_start, $target_end];
        }
    }
    elsif ($type eq "stop_codon") {
        my %attrs;
        foreach my $kv (split /;/, $attr) {
            if ($kv =~ /^(\w+)=(.*)/) {
                $attrs{$1} = $2;
            }
        }
        my $parent = $attrs{Parent} || $current_mRNA_id;
        $mrna_has_stop{$parent} = 1;
    }
}
close IN;

my $total_alignments = scalar @mrna_order;
print STDERR "Parsed $total_alignments miniprot alignments.\n";

# Calculate coverage for each alignment and filter
# Coverage = aligned protein residues / total protein length
# The mRNA-level Target gives overall protein coordinates aligned
my %mrna_coverage;
my %mrna_keep;
foreach my $mRNA_id (@mrna_order) {
    my $data = $mrna_data{$mRNA_id};
    my $prot_len = $data->{protein_length};
    my $coverage = 0;
    if ($prot_len > 0 && $data->{target_start} > 0 && $data->{target_end} > 0) {
        $coverage = ($data->{target_end} - $data->{target_start} + 1) / $prot_len;
    }
    $mrna_coverage{$mRNA_id} = $coverage;

    # Keep alignments that pass minimum thresholds
    if ($coverage >= $min_coverage && $data->{identity} >= $min_identity) {
        $mrna_keep{$mRNA_id} = 1;
    }
    elsif ($coverage < $min_coverage || $data->{identity} < $min_identity) {
        # Still keep as poor class if we have valid CDS data
        if (scalar @{$mrna_cds{$mRNA_id}} > 0) {
            $mrna_keep{$mRNA_id} = 1;
        }
    }
}

# Group alignments into gene loci based on genomic overlap on the same strand.
# Sort alignments by chromosome, strand, start position.
print STDERR "Grouping alignments into gene loci...\n";
my @sorted_mrna = sort {
    $mrna_data{$a}{chr} cmp $mrna_data{$b}{chr} ||
    $mrna_data{$a}{strand} cmp $mrna_data{$b}{strand} ||
    $mrna_data{$a}{start} <=> $mrna_data{$b}{start}
} @mrna_order;

my @loci;           # array of arrays: each locus is a list of mRNA IDs
my $current_locus_chr = "";
my $current_locus_strand = "";
my $current_locus_end = 0;
my @current_locus;

foreach my $mRNA_id (@sorted_mrna) {
    my $data = $mrna_data{$mRNA_id};
    if ($data->{chr} eq $current_locus_chr &&
        $data->{strand} eq $current_locus_strand &&
        $data->{start} <= $current_locus_end) {
        # Overlapping with current locus
        push @current_locus, $mRNA_id;
        $current_locus_end = $data->{end} if $data->{end} > $current_locus_end;
    }
    else {
        # Start a new locus
        if (@current_locus) {
            push @loci, [@current_locus];
        }
        @current_locus = ($mRNA_id);
        $current_locus_chr = $data->{chr};
        $current_locus_strand = $data->{strand};
        $current_locus_end = $data->{end};
    }
}
if (@current_locus) {
    push @loci, [@current_locus];
}

print STDERR "Found " . scalar(@loci) . " gene loci.\n";

# For each locus, pick the best alignment.
# Scoring: higher coverage * identity * alignment_score is better.
# Then classify into A/B/C/D categories.
print STDERR "Selecting best gene model per locus and classifying...\n";

# Open output files
my $alignment_gff3_file = "$tmp_dir/homolog_alignment.gff3";
my $raw_gff3_file = "$tmp_dir/homolog_prediction.raw.gff3";
open ALIGN_OUT, ">", $alignment_gff3_file or die "Can not create file $alignment_gff3_file, $!";
open RAW_OUT, ">", $raw_gff3_file or die "Can not create file $raw_gff3_file, $!";

my ($numA, $numB, $numC, $numD) = (0, 0, 0, 0);
my $gene_num = 0;
my @all_gff3_blocks;  # for final output

foreach my $locus_ref (@loci) {
    my @locus_members = @$locus_ref;

    # Score and sort locus members: prefer higher coverage, then higher identity, then higher AS score
    my @scored = sort {
        my $score_a = ($mrna_coverage{$a} * 100) + ($mrna_data{$a}{identity} * 10) + (($paf_data{$a}{as_score} || $mrna_data{$a}{score} || 0) / 1000);
        my $score_b = ($mrna_coverage{$b} * 100) + ($mrna_data{$b}{identity} * 10) + (($paf_data{$b}{as_score} || $mrna_data{$b}{score} || 0) / 1000);
        $score_b <=> $score_a;
    } @locus_members;

    # Output alignment GFF3 for top alignments in this locus (up to 5)
    my $align_count = 0;
    foreach my $mRNA_id (@scored) {
        last if $align_count >= 5;
        my $align_gff3 = &generate_alignment_gff3($mRNA_id);
        print ALIGN_OUT $align_gff3 if $align_gff3;
        $align_count ++;
    }

    # Pick the best gene model
    my $best_id = $scored[0];
    next unless $best_id;
    next unless scalar @{$mrna_cds{$best_id}} > 0;

    my $data = $mrna_data{$best_id};
    my $coverage = $mrna_coverage{$best_id};
    my $identity = $data->{identity};

    $gene_num ++;
    my $geneID = "gene$gene_num";

    # Classify gene model
    my $type;
    my $has_stop = $mrna_has_stop{$best_id} || 0;

    # Check for start codon
    my $has_start = &check_start_codon($best_id);

    if ($coverage >= 0.8 && $identity >= 0.6 && $has_start && $has_stop) {
        $type = "excellent_gene_models_predicted_by_homolog";
        $numA ++;
    }
    elsif ($coverage >= 0.6 && $identity >= 0.4) {
        $type = "good_gene_models_predicted_by_homolog";
        $numB ++;
    }
    elsif ($coverage >= $min_coverage && $identity >= $min_identity) {
        $type = "fair_gene_models_predicted_by_homolog";
        $numC ++;
    }
    else {
        $type = "poor_gene_models_predicted_by_homolog";
        $numD ++;
    }

    # Count intron support from other alignments at this locus
    my %intron_support;
    foreach my $mRNA_id (@scored) {
        my @cds_list = sort { $a->[1] <=> $b->[1] } @{$mrna_cds{$mRNA_id}};
        for (my $i = 0; $i < $#cds_list; $i++) {
            my $intron_start = $cds_list[$i][2] + 1;
            my $intron_end = $cds_list[$i+1][1] - 1;
            if ($intron_start < $intron_end) {
                $intron_support{"$intron_start\t$intron_end"} ++;
            }
        }
    }

    # Generate GETA-format GFF3 for this gene model
    my $gff3_block = &generate_gene_gff3($best_id, $geneID, $type, \%intron_support);

    push @all_gff3_blocks, $gff3_block;

    # Also write to raw GFF3
    print RAW_OUT "$gff3_block\n";
}

close ALIGN_OUT;
close RAW_OUT;

# Output to STDOUT: all classified gene models (to be further filtered by the caller)
foreach my $block (@all_gff3_blocks) {
    print "$block\n";
}

my $total = $numA + $numB + $numC + $numD;
print STDERR "Gene model classification: A (excellent) $numA, B (good) $numB, C (fair) $numC, D (poor) $numD. Total: $total.\n";


############################
# Subroutines
############################

# Generate alignment GFF3 (protein_match features) for a single mRNA alignment
sub generate_alignment_gff3 {
    my $mRNA_id = shift;
    my $data = $mrna_data{$mRNA_id};
    my @cds_list = @{$mrna_cds{$mRNA_id}};
    return "" unless @cds_list;

    my $chr = $data->{chr};
    my $strand = $data->{strand};
    my $homolog_name = $data->{target_name};
    my $source = "miniprot";

    # Sort CDS by position
    @cds_list = sort { $a->[1] <=> $b->[1] } @cds_list;

    my $out = "";
    my ($frame, $length) = (0, 0);

    # Sort for frame calculation: forward by start, reverse by end descending
    my @frame_sorted = @cds_list;
    @frame_sorted = sort { $b->[1] <=> $a->[1] } @frame_sorted if $strand eq "-";

    foreach my $cds (@frame_sorted) {
        my ($c_chr, $c_start, $c_end, $c_strand, $c_phase) = @$cds;
        $length += ($c_end - $c_start + 1);
        $out .= "$chr\t$source\tprotein_match\t$c_start\t$c_end\t.\t$strand\t$frame\tID=$homolog_name;Name=$homolog_name\n";
        $frame = $length % 3;
        if ( $frame == 1 ) { $frame = 2; }
        elsif ( $frame == 2 ) { $frame = 1; }
    }

    return $out;
}


# Generate GETA-format GFF3 for a gene model
sub generate_gene_gff3 {
    my ($mRNA_id, $geneID, $type, $intron_support_ref) = @_;
    my %intron_support = %$intron_support_ref;
    my $data = $mrna_data{$mRNA_id};
    my @cds_list = @{$mrna_cds{$mRNA_id}};

    my $chr = $data->{chr};
    my $strand = $data->{strand};
    my $homolog_name = $data->{target_name};
    my $homolog_length = $data->{protein_length};
    my $identity = $data->{identity};
    my $coverage_pct = int($mrna_coverage{$mRNA_id} * 10000 + 0.5) / 100;
    my $source = "miniprot";

    # Sort CDS by genomic position
    @cds_list = sort { $a->[1] <=> $b->[1] } @cds_list;

    # Get gene boundaries (include stop_codon if present)
    my $gene_start = $cds_list[0][1];
    my $gene_end = $cds_list[-1][2];

    # If stop_codon feature exists, the gene region may extend 3bp beyond last CDS
    if ($mrna_has_stop{$mRNA_id}) {
        if ($strand eq "+") {
            my $stop_end = $cds_list[-1][2] + 3;
            $gene_end = $stop_end if $stop_end <= length($genome_seq{$chr} || "");
            # Actually include stop codon in last CDS (GETA convention: last CDS includes stop codon)
            $cds_list[-1][2] += 3 if ($cds_list[-1][2] + 3) <= length($genome_seq{$chr} || "");
        }
        else {
            my $stop_start = $cds_list[0][1] - 3;
            $gene_start = $stop_start if $stop_start >= 1;
            $cds_list[0][1] -= 3 if ($cds_list[0][1] - 3) >= 1;
        }
    }

    # Calculate introns from CDS
    my @introns;
    for (my $i = 0; $i < $#cds_list; $i++) {
        my $intron_start = $cds_list[$i][2] + 1;
        my $intron_end = $cds_list[$i+1][1] - 1;
        if ($intron_start <= $intron_end) {
            push @introns, [$intron_start, $intron_end];
        }
    }

    # Build GFF3 output
    my $identity_pct = int($identity * 10000 + 0.5) / 100;
    my $gff3_out = "";

    # Gene line
    $gff3_out .= "$chr\t$source\tgene\t$gene_start\t$gene_end\t.\t$strand\t.\tID=$geneID;Name=$geneID;Type=$type;Homolog_name=$homolog_name;Homolog_length=$homolog_length;Blastx_coverage=$coverage_pct\%;Blastx_identity=$identity_pct;Source=$source;\n";

    # mRNA line
    $gff3_out .= "$chr\t$source\tmRNA\t$gene_start\t$gene_end\t.\t$strand\t.\tID=$geneID.mRNA;Name=$geneID.mRNA;Parent=$geneID;Type=$type;Homolog_name=$homolog_name;Homolog_length=$homolog_length;Blastx_coverage=$coverage_pct\%;Blastx_identity=$identity_pct;Source=$source;\n";

    # CDS and exon lines (sorted by position for frame calculation)
    my ($frame, $length, $num) = (0, 0, 0);
    my %feature_lines;

    # For frame calculation: sort forward for +, reverse for -
    my @frame_cds = @cds_list;
    @frame_cds = sort { $b->[1] <=> $a->[1] } @frame_cds if $strand eq "-";

    foreach my $cds (@frame_cds) {
        $num ++;
        my ($c_chr, $c_start, $c_end) = @$cds;
        $length += ($c_end - $c_start + 1);

        $feature_lines{"$chr\t$source\tCDS\t$c_start\t$c_end\t.\t$strand\t$frame\tID=$geneID.mRNA.CDS$num;Parent=$geneID.mRNA;\n"} = $c_start;
        $feature_lines{"$chr\t$source\texon\t$c_start\t$c_end\t.\t$strand\t.\tID=$geneID.mRNA.exon$num;Parent=$geneID.mRNA;\n"} = $c_start;

        $frame = $length % 3;
        if ( $frame == 1 ) { $frame = 2; }
        elsif ( $frame == 2 ) { $frame = 1; }
    }

    # Intron lines
    $num = 0;
    my @sorted_introns = @introns;
    @sorted_introns = sort { $b->[0] <=> $a->[0] } @sorted_introns if $strand eq "-";

    foreach my $intron (@sorted_introns) {
        $num ++;
        my ($i_start, $i_end) = @$intron;
        my $supported_times = 1;
        my $key = "$i_start\t$i_end";
        $supported_times = $intron_support{$key} if exists $intron_support{$key};
        $feature_lines{"$chr\t$source\tintron\t$i_start\t$i_end\t.\t$strand\t.\tID=$geneID.mRNA.intron$num;Parent=$geneID.mRNA;Supported_times=$supported_times;\n"} = $i_start;
    }

    # Sort features by position, then by type (intron/CDS/exon ordering)
    foreach (sort { $feature_lines{$a} <=> $feature_lines{$b} or $b cmp $a } keys %feature_lines) {
        $gff3_out .= $_;
    }

    return $gff3_out;
}


# Check if the gene model starts with a start codon
sub check_start_codon {
    my $mRNA_id = shift;
    my $data = $mrna_data{$mRNA_id};
    my @cds_list = @{$mrna_cds{$mRNA_id}};
    return 0 unless @cds_list;

    my $chr = $data->{chr};
    my $strand = $data->{strand};
    my $genome_seq = $genome_seq{$chr};
    return 0 unless defined $genome_seq;

    # Sort CDS by position
    @cds_list = sort { $a->[1] <=> $b->[1] } @cds_list;

    my $codon;
    if ($strand eq "+") {
        my $start_pos = $cds_list[0][1] - 1;  # 0-based
        return 0 if $start_pos < 0 || $start_pos + 3 > length($genome_seq);
        $codon = substr($genome_seq, $start_pos, 3);
    }
    else {
        my $end_pos = $cds_list[-1][2] - 3;  # 0-based position for last 3 bases
        return 0 if $end_pos < 0 || $end_pos + 3 > length($genome_seq);
        $codon = substr($genome_seq, $end_pos, 3);
        $codon = &reverse_complement($codon);
    }

    return exists $start_codon{$codon} ? 1 : 0;
}


sub reverse_complement {
    my $seq = shift;
    $seq = reverse $seq;
    $seq =~ tr/ATCGatcg/TAGCtagc/;
    return $seq;
}


# Generate codon table based on genetic code
sub codon_table {
    my $code = shift || 1;

    # Standard genetic code (code 1)
    my %codon = (
        "TTT" => "F", "TTC" => "F", "TTA" => "L", "TTG" => "L",
        "TCT" => "S", "TCC" => "S", "TCA" => "S", "TCG" => "S",
        "TAT" => "Y", "TAC" => "Y", "TAA" => "*", "TAG" => "*",
        "TGT" => "C", "TGC" => "C", "TGA" => "*", "TGG" => "W",
        "CTT" => "L", "CTC" => "L", "CTA" => "L", "CTG" => "L",
        "CCT" => "P", "CCC" => "P", "CCA" => "P", "CCG" => "P",
        "CAT" => "H", "CAC" => "H", "CAA" => "Q", "CAG" => "Q",
        "CGT" => "R", "CGC" => "R", "CGA" => "R", "CGG" => "R",
        "ATT" => "I", "ATC" => "I", "ATA" => "I", "ATG" => "M",
        "ACT" => "T", "ACC" => "T", "ACA" => "T", "ACG" => "T",
        "AAT" => "N", "AAC" => "N", "AAA" => "K", "AAG" => "K",
        "AGT" => "S", "AGC" => "S", "AGA" => "R", "AGG" => "R",
        "GTT" => "V", "GTC" => "V", "GTA" => "V", "GTG" => "V",
        "GCT" => "A", "GCC" => "A", "GCA" => "A", "GCG" => "A",
        "GAT" => "D", "GAC" => "D", "GAA" => "E", "GAG" => "E",
        "GGT" => "G", "GGC" => "G", "GGA" => "G", "GGG" => "G",
    );

    # Start codons for standard code
    my %start_codon = ("ATG" => 1, "CTG" => 1, "TTG" => 1);
    my %stop_codon = ("TAA" => 1, "TAG" => 1, "TGA" => 1);

    # Modify for alternative genetic codes
    if ($code == 2) {
        # Vertebrate mitochondrial
        $codon{"AGA"} = "*"; $codon{"AGG"} = "*";
        $codon{"ATA"} = "M"; $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1, "AGA" => 1, "AGG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"ATA"} = 1; $start_codon{"ATT"} = 1; $start_codon{"ATC"} = 1; $start_codon{"GTG"} = 1;
    }
    elsif ($code == 3) {
        # Yeast mitochondrial
        $codon{"CTT"} = "T"; $codon{"CTC"} = "T"; $codon{"CTA"} = "T"; $codon{"CTG"} = "T";
        $codon{"ATA"} = "M"; $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"ATA"} = 1; $start_codon{"GTG"} = 1;
    }
    elsif ($code == 4) {
        # Mold, Protozoan, Coelenterate mitochondrial
        $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"ATA"} = 1; $start_codon{"ATT"} = 1; $start_codon{"ATC"} = 1; $start_codon{"GTG"} = 1;
    }
    elsif ($code == 5) {
        # Invertebrate mitochondrial
        $codon{"AGA"} = "S"; $codon{"AGG"} = "S";
        $codon{"ATA"} = "M"; $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"ATA"} = 1; $start_codon{"ATT"} = 1; $start_codon{"ATC"} = 1; $start_codon{"GTG"} = 1;
    }
    elsif ($code == 6) {
        # Ciliate, Dasycladacean, Hexamita
        $codon{"TAA"} = "Q"; $codon{"TAG"} = "Q";
        %stop_codon = ("TGA" => 1);
        delete $stop_codon{"TAA"}; delete $stop_codon{"TAG"};
    }
    elsif ($code == 9) {
        # Echinoderm and Flatworm mitochondrial
        $codon{"AAA"} = "N"; $codon{"AGA"} = "S"; $codon{"AGG"} = "S"; $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"GTG"} = 1;
    }
    elsif ($code == 10) {
        # Euplotid nuclear
        $codon{"TGA"} = "C";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
    }
    elsif ($code == 11) {
        # Bacterial, Archaeal, Plant plastid
        $start_codon{"GTG"} = 1; $start_codon{"ATT"} = 1; $start_codon{"ATC"} = 1; $start_codon{"ATA"} = 1;
    }
    elsif ($code == 12) {
        # Alternative Yeast nuclear
        $codon{"CTG"} = "S";
        delete $start_codon{"CTG"};
    }
    elsif ($code == 13) {
        # Ascidian mitochondrial
        $codon{"AGA"} = "G"; $codon{"AGG"} = "G"; $codon{"ATA"} = "M"; $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"ATA"} = 1; $start_codon{"GTG"} = 1; $start_codon{"TTG"} = 1;
    }
    elsif ($code == 14) {
        # Alternative Flatworm mitochondrial
        $codon{"AAA"} = "N"; $codon{"AGA"} = "S"; $codon{"AGG"} = "S";
        $codon{"TAA"} = "Y"; $codon{"TGA"} = "W";
        %stop_codon = ("TAG" => 1);
        delete $stop_codon{"TAA"}; delete $stop_codon{"TGA"};
    }
    elsif ($code == 15) {
        # Blepharisma nuclear
        $codon{"TAG"} = "Q";
        %stop_codon = ("TAA" => 1, "TGA" => 1);
        delete $stop_codon{"TAG"};
    }
    elsif ($code == 16) {
        # Chlorophycean mitochondrial
        $codon{"TAG"} = "L";
        %stop_codon = ("TAA" => 1, "TGA" => 1);
        delete $stop_codon{"TAG"};
    }
    elsif ($code == 21) {
        # Trematode mitochondrial
        $codon{"TGA"} = "W"; $codon{"ATA"} = "M"; $codon{"AGA"} = "S"; $codon{"AGG"} = "S"; $codon{"AAA"} = "N";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"GTG"} = 1;
    }
    elsif ($code == 22) {
        # Scenedesmus obliquus mitochondrial
        $codon{"TCA"} = "*"; $codon{"TAG"} = "L";
        $stop_codon{"TCA"} = 1;
        delete $stop_codon{"TAG"};
    }
    elsif ($code == 23) {
        # Thraustochytrium mitochondrial
        $codon{"TTA"} = "*";
        $stop_codon{"TTA"} = 1;
        $start_codon{"ATT"} = 1; $start_codon{"GTG"} = 1;
    }
    elsif ($code == 24) {
        # Rhabdopleuridae mitochondrial
        $codon{"AGA"} = "S"; $codon{"AGG"} = "K"; $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"GTG"} = 1; $start_codon{"CTG"} = 1; $start_codon{"TTG"} = 1;
    }
    elsif ($code == 25) {
        # Candidate Division SR1 and Gracilibacteria
        $codon{"TGA"} = "G";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
        $start_codon{"GTG"} = 1; $start_codon{"CTG"} = 1; $start_codon{"TTG"} = 1;
    }
    elsif ($code == 26) {
        # Pachysolen tannophilus nuclear
        $codon{"CTG"} = "A";
        delete $start_codon{"CTG"};
    }
    elsif ($code == 29) {
        # Mesodinium nuclear
        $codon{"TAA"} = "Y"; $codon{"TAG"} = "Y";
        %stop_codon = ("TGA" => 1);
        delete $stop_codon{"TAA"}; delete $stop_codon{"TAG"};
    }
    elsif ($code == 30) {
        # Peritrich nuclear
        $codon{"TAA"} = "E"; $codon{"TAG"} = "E";
        %stop_codon = ("TGA" => 1);
        delete $stop_codon{"TAA"}; delete $stop_codon{"TAG"};
    }
    elsif ($code == 31) {
        # Blastocrithidia nuclear
        $codon{"TGA"} = "W";
        %stop_codon = ("TAA" => 1, "TAG" => 1);
        delete $stop_codon{"TGA"};
    }
    elsif ($code == 33) {
        # Cephalodiscidae mitochondrial
        $codon{"AGA"} = "S"; $codon{"AGG"} = "K"; $codon{"TGA"} = "Y"; $codon{"TAA"} = "Y";
        %stop_codon = ("TAG" => 1);
        delete $stop_codon{"TAA"}; delete $stop_codon{"TGA"};
    }

    return (\%codon, \%start_codon, \%stop_codon);
}

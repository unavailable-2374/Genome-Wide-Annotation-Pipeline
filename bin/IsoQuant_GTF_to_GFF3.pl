#!/usr/bin/perl
use strict;
use Getopt::Long;

my $usage = <<USAGE;
Usage:
    perl $0 [options] transcript_models.gtf > output.gff3

    This script converts IsoQuant's transcript_models.gtf output to GETA-compatible
    GFF3 format with gene -> mRNA -> exon hierarchy.

    It groups transcripts by gene_id from the GTF attributes, creates gene features,
    and preserves IsoQuant's transcript classification if available.

    --source <string>       GFF3 source field (default: IsoQuant)
    --gene_prefix <string>  Gene ID prefix (default: isoquant)
    --help                  Display this help and exit

USAGE
if (@ARGV == 0 && -t STDIN) { die $usage }

my ($source, $gene_prefix, $help);
GetOptions(
    "source:s" => \$source,
    "gene_prefix:s" => \$gene_prefix,
    "help" => \$help,
);
if ($help) { die $usage }

$source ||= "IsoQuant";
$gene_prefix ||= "isoquant";

# Read GTF input
my $fh;
if (@ARGV) {
    open $fh, '<', $ARGV[0] or die "Error: cannot open file $ARGV[0]: $!\n";
}
else {
    $fh = \*STDIN;
}

# Parse IsoQuant GTF
# GTF format: chr source feature start end score strand frame attributes
# Attributes contain: gene_id "xxx"; transcript_id "yyy"; possibly transcript_type "zzz";
# IsoQuant outputs transcript and exon features

my (%genes, %transcripts, %transcript_exons, @gene_order, %gene_seen);
my (%transcript_classification, %transcript_gene);

while (<$fh>) {
    chomp;
    next if /^#/;
    next if /^\s*$/;

    my @fields = split /\t/;
    next unless @fields == 9;

    my ($chr, $src, $type, $start, $end, $score, $strand, $frame, $attr) = @fields;

    # Parse GTF attributes
    my $gene_id = $1 if $attr =~ /gene_id\s+"([^"]+)"/;
    my $transcript_id = $1 if $attr =~ /transcript_id\s+"([^"]+)"/;
    my $transcript_type = $1 if $attr =~ /transcript_type\s+"([^"]+)"/;
    # IsoQuant may also use structural_category
    my $structural_category = $1 if $attr =~ /structural_category\s+"([^"]+)"/;

    next unless defined $gene_id;

    # Track gene order
    unless (exists $gene_seen{$gene_id}) {
        $gene_seen{$gene_id} = 1;
        push @gene_order, $gene_id;
    }

    if ($type eq "transcript" || $type eq "mRNA") {
        $transcripts{$transcript_id} = {
            chr => $chr,
            start => $start,
            end => $end,
            score => $score,
            strand => $strand,
        };
        $transcript_gene{$transcript_id} = $gene_id;

        # Store classification if present
        if (defined $transcript_type) {
            $transcript_classification{$transcript_id} = $transcript_type;
        }
        elsif (defined $structural_category) {
            $transcript_classification{$transcript_id} = $structural_category;
        }

        # Initialize or update gene boundaries
        if (exists $genes{$gene_id}) {
            $genes{$gene_id}{start} = $start if $start < $genes{$gene_id}{start};
            $genes{$gene_id}{end} = $end if $end > $genes{$gene_id}{end};
            push @{$genes{$gene_id}{transcripts}}, $transcript_id;
        }
        else {
            $genes{$gene_id} = {
                chr => $chr,
                start => $start,
                end => $end,
                strand => $strand,
                transcripts => [$transcript_id],
            };
        }
    }
    elsif ($type eq "exon") {
        push @{$transcript_exons{$transcript_id}}, {
            chr => $chr,
            start => $start,
            end => $end,
            strand => $strand,
            frame => $frame,
        };
    }
}
close $fh if @ARGV;

# Handle case where GTF has no explicit transcript lines:
# Build gene and transcript info from exon lines alone
foreach my $tid (keys %transcript_exons) {
    unless (exists $transcripts{$tid}) {
        my @exons = @{$transcript_exons{$tid}};
        my $min_start = $exons[0]->{start};
        my $max_end = $exons[0]->{end};
        foreach my $exon (@exons) {
            $min_start = $exon->{start} if $exon->{start} < $min_start;
            $max_end = $exon->{end} if $exon->{end} > $max_end;
        }
        $transcripts{$tid} = {
            chr => $exons[0]->{chr},
            start => $min_start,
            end => $max_end,
            score => ".",
            strand => $exons[0]->{strand},
        };

        my $gid = $transcript_gene{$tid};
        if (defined $gid) {
            if (exists $genes{$gid}) {
                $genes{$gid}{start} = $min_start if $min_start < $genes{$gid}{start};
                $genes{$gid}{end} = $max_end if $max_end > $genes{$gid}{end};
                # Only add if not already present
                my %existing = map { $_ => 1 } @{$genes{$gid}{transcripts}};
                push @{$genes{$gid}{transcripts}}, $tid unless $existing{$tid};
            }
            else {
                $genes{$gid} = {
                    chr => $exons[0]->{chr},
                    start => $min_start,
                    end => $max_end,
                    strand => $exons[0]->{strand},
                    transcripts => [$tid],
                };
                unless (exists $gene_seen{$gid}) {
                    push @gene_order, $gid;
                    $gene_seen{$gid} = 1;
                }
            }
        }
    }
}

# Output GFF3 header
print "##gff-version 3\n";

# Output genes in order, with sequential IDs
my $gene_num = 0;

foreach my $orig_gene_id (@gene_order) {
    my $gene = $genes{$orig_gene_id};
    next unless $gene && $gene->{transcripts} && @{$gene->{transcripts}} > 0;

    $gene_num++;
    my $new_gene_id = $gene_prefix . $gene_num;

    # Gene line
    print join("\t",
        $gene->{chr}, $source, "gene",
        $gene->{start}, $gene->{end},
        ".", $gene->{strand}, ".",
        "ID=$new_gene_id;"
    ) . "\n";

    # Sort transcripts by start position
    my @sorted_tids = sort {
        $transcripts{$a}->{start} <=> $transcripts{$b}->{start} ||
        $transcripts{$a}->{end} <=> $transcripts{$b}->{end}
    } @{$gene->{transcripts}};

    my $mrna_num = 0;
    foreach my $tid (@sorted_tids) {
        my $tinfo = $transcripts{$tid};
        next unless $tinfo;
        $mrna_num++;
        my $new_mrna_id = "$new_gene_id.t$mrna_num";

        # Build mRNA attribute string
        my $mrna_attr = "ID=$new_mrna_id;Parent=$new_gene_id";
        if (exists $transcript_classification{$tid}) {
            $mrna_attr .= ";Classification=$transcript_classification{$tid}";
        }
        $mrna_attr .= ";Source=$source";

        # mRNA line
        print join("\t",
            $tinfo->{chr}, $source, "mRNA",
            $tinfo->{start}, $tinfo->{end},
            ".", $tinfo->{strand}, ".",
            $mrna_attr
        ) . "\n";

        # Exon lines - sort by start position
        my @exons;
        if (exists $transcript_exons{$tid}) {
            @exons = sort { $a->{start} <=> $b->{start} } @{$transcript_exons{$tid}};
        }

        my $exon_num = 0;
        foreach my $exon (@exons) {
            $exon_num++;
            print join("\t",
                $exon->{chr}, $source, "exon",
                $exon->{start}, $exon->{end},
                ".", $exon->{strand}, ".",
                "ID=$new_mrna_id.exon$exon_num;Parent=$new_mrna_id;"
            ) . "\n";
        }
    }

    # Blank line to separate gene blocks
    print "\n";
}

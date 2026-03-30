# GWAP v3.0 — Genome-Wide Annotation Pipeline

A fully automated eukaryotic genome annotation pipeline with **long-read RNA-Seq as first-class input**. Built on top of [GETA](https://github.com/chenlianfu/geta), re-engineered with modern tools for speed, accuracy, and minimal dependencies.

## What's New in v3.0

| Area | v2 (legacy) | v3 |
|------|-------------|-----|
| Transcript evidence | Trimmomatic + HISAT2 (short reads only) | **minimap2 + IsoQuant + SQANTI3** (long reads primary); fastp + STAR (short reads optional) |
| Homolog prediction | MMseqs2 + exonerate / genewise / gth | **miniprot** (single tool, >50x faster) |
| Quality assessment | BUSCO | **compleasm** (miniprot-based, much faster) |
| Repeat annotation | RepeatModeler + RepeatMasker | Same, plus optional **EDTA** for plant genomes |
| AUGUSTUS hints | intron + evidence models | + **miniprothint** protein confidence scoring |
| Gene model QC | hmmscan + diamond | + optional **PSAURON** deep-learning scoring |
| Functional annotation | None | Optional **eggNOG-mapper** (GO/KEGG/COG) |
| ncRNA annotation | None | Optional **tRNAscan-SE + Infernal/Rfam** |
| Dependencies | 16 required tools | **12 core** (removed exonerate, genewise, gth, GNU parallel, Java) |

## Pipeline Overview

```
                         +-----------------+
                         |  Genome (FASTA) |
                         +--------+--------+
                                  |
                  +---------------+---------------+
                  |                               |
         Step 1: Repeat Masking          Step 0: Prep & Config
         RepeatModeler/EDTA +                     |
         RepeatMasker + Dfam                      |
                  |                               |
                  +-------+-----------------------+
                          |
            +-------------+-------------+
            |                           |
   Step 2: Homolog Prediction   Step 3: Transcript Prediction
        miniprot                   Long reads (primary):
            |                        minimap2 -> IsoQuant ->
            |                        SQANTI3 -> TransDecoder
            |                      Short reads (optional):
            |                        fastp -> STAR -> StringTie2
            |                           |
            +-------------+-------------+
                          |
                 Step 4: AUGUSTUS
                 Training (BGM2AT) +
                 Hints (miniprothint) +
                 Prediction (parallel)
                          |
                 Step 5: Integration
                 Fill + Merge + Filter +
                 HMM/BLASTP validation +
                 Alternative splicing
                          |
                 Step 6: Output
                 GFF3/GTF + compleasm +
                 eggNOG + ncRNA (optional)
```

## Three Running Modes

```bash
# Mode 1: Long reads + homolog proteins (recommended, minimal input)
perl bin/geta.pl --genome genome.fa \
     --long_reads flnc.bam --long_read_type pacbio_hifi \
     --protein homolog.fa --cpu 48

# Mode 2: Long reads + short reads assist + homolog proteins (best quality)
perl bin/geta.pl --genome genome.fa \
     --long_reads flnc.bam --long_read_type pacbio_hifi \
     --pe1 lib.1.fq.gz --pe2 lib.2.fq.gz \
     --protein homolog.fa --cpu 48

# Mode 3: Short reads only (backward compatible with v2)
perl bin/geta.pl --genome genome.fa \
     --pe1 lib.1.fq.gz --pe2 lib.2.fq.gz \
     --protein homolog.fa --cpu 48
```

## Requirements

### Core Dependencies (12)

| Tool | Version Tested | Purpose |
|------|---------------|---------|
| [minimap2](https://github.com/lh3/minimap2) | 2.28+ | Long-read RNA-Seq alignment |
| [miniprot](https://github.com/lh3/miniprot) | 0.18+ | Protein-to-genome splice-aware alignment |
| [IsoQuant](https://github.com/ablab/IsoQuant) | 3.12+ | Long-read transcript discovery (`pip install isoquant`) |
| [SQANTI3](https://github.com/ConesaLab/SQANTI3) | 6.0+ | Long-read transcript QC and filtering |
| [TransDecoder](https://github.com/TransDecoder/TransDecoder) | 5.5+ | ORF prediction from transcripts |
| [AUGUSTUS](https://github.com/Gaius-Augustus/Augustus) | 3.5.0 | Ab initio gene prediction with hints |
| [RepeatMasker](http://www.repeatmasker.org/) | 4.1.7 | Repeat sequence masking (Dfam database) |
| [RepeatModeler](http://www.repeatmasker.org/RepeatModeler/) | 2.0.5 | De novo repeat library construction |
| [samtools](http://www.htslib.org/) | 1.17+ | BAM/SAM manipulation |
| [diamond](https://github.com/bbuchfink/diamond) | 2.1+ | Fast protein BLASTP for gene model filtering |
| [HMMER](http://hmmer.org/) | 3.3+ | HMM-based gene model validation (hmmscan) |
| [compleasm](https://github.com/huangnengCSU/compleasm) | latest | Gene set completeness assessment (`pip install compleasm`) |

### Optional Dependencies

| Tool | Flag | Purpose |
|------|------|---------|
| [STAR](https://github.com/alexdobin/STAR) | `--pe1/--pe2` with `--aligner star` | Short-read RNA-Seq alignment (default when short reads provided) |
| [fastp](https://github.com/OpenGene/fastp) | `--pe1/--pe2` | Short-read quality control |
| [HISAT2](https://ccb.jhu.edu/software/hisat2/) | `--aligner hisat2` | Low-memory alternative to STAR |
| [EDTA](https://github.com/oushujun/EDTA) | `--TE_annotator edta` | Enhanced TE annotation for plant genomes |
| [miniprothint](https://github.com/tomasbruna/miniprothint) | auto (when protein provided) | Confidence-scored protein hints for AUGUSTUS |
| [PSAURON](https://github.com/salzberg-lab/PSAURON) | `--enable_psauron` | Deep-learning gene model quality scoring |
| [eggNOG-mapper](https://github.com/eggnogdb/eggnog-mapper) | `--enable_eggnog` | Functional annotation (GO/KEGG/COG) |
| [tRNAscan-SE](http://lowelab.ucsc.edu/tRNAscan-SE/) | `--enable_ncrna` | tRNA prediction |
| [Infernal](http://eddylab.org/infernal/) | `--enable_ncrna` | ncRNA annotation against Rfam |
| [gffread](http://ccb.jhu.edu/software/stringtie/gff.shtml) | required for long-read mode | GFF/GTF manipulation |
| [BLAST+](https://blast.ncbi.nlm.nih.gov/) | rmblastn for RepeatMasker | Repeat masking engine |
| [ParaFly](https://sourceforge.net/projects/parafly/) | always | Parallel command execution |

## Installation

```bash
# Clone the repository
git clone https://github.com/unavailable-2374/Genome-Wide-Annotation-Pipeline.git
cd Genome-Wide-Annotation-Pipeline

# Add bin/ to PATH
export PATH=$(pwd)/bin:$PATH

# Install Python dependencies
pip install isoquant compleasm

# Install core tools via conda/mamba (recommended)
mamba install -c bioconda minimap2 miniprot samtools diamond hmmer \
  augustus repeatmasker repeatmodeler star fastp gffread transdecoder
```

Ensure `$AUGUSTUS_CONFIG_PATH` is set and writable:

```bash
export AUGUSTUS_CONFIG_PATH=/path/to/augustus/config/
```

## Parameters

### Input

| Parameter | Description |
|-----------|-------------|
| `--genome <file>` | **(required)** Genome FASTA file |
| `--long_reads <file>` | PacBio FLNC / Nanopore FASTQ or BAM (comma-separated for multiple) |
| `--long_read_type <str>` | `pacbio_hifi` (default) \| `nanopore_cdna` \| `nanopore_drna` |
| `--pe1 <file> --pe2 <file>` | Paired-end short-read FASTQ files (comma-separated, .gz supported) |
| `--se <file>` | Single-end short-read FASTQ files |
| `--sam <file>` | Pre-aligned SAM/BAM files |
| `--protein <file>` | Homologous protein sequences from related species (recommended: 3-10 species) |
| `--RM_species_Dfam <str>` | Dfam species/clade name for RepeatMasker (e.g. `Viridiplantae`, `Metazoa`) |
| `--RM_lib <file>` | Custom repeat library FASTA |
| `--HMM_db <file>` | Pfam HMM database path(s) for gene model filtering (comma-separated) |
| `--BUSCO_lineage_dataset <file>` | compleasm lineage dataset name(s) |

At least one of `--long_reads`, `--pe1/--pe2`, `--se`, `--sam`, or `--protein` must be provided.

### Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--cpu <int>` | 4 | CPU threads |
| `--aligner <str>` | star | Short-read aligner: `star` or `hisat2` |
| `--TE_annotator <str>` | repeatmodeler | TE annotator: `repeatmodeler` or `edta` (recommended for plants) |
| `--strand_specific` | off | Treat RNA-Seq data as strand-specific |
| `--genetic_code <int>` | 1 | NCBI genetic code table |
| `--homolog_prediction_method <str>` | miniprot | Homolog alignment method |
| `--optimize_augustus_method <int>` | 3 | AUGUSTUS optimization: 1=fast, 2=thorough, 3=both |
| `--config <file>` | auto | Custom configuration file (auto-selected by genome size) |
| `--no_RepeatModeler` | off | Skip RepeatModeler (use with pre-masked genome) |
| `--no_alternative_splicing_analysis` | off | Skip alternative splicing analysis |

### Optional Features

| Parameter | Description |
|-----------|-------------|
| `--enable_psauron` | Run PSAURON deep-learning quality scoring on gene models |
| `--enable_eggnog` | Run eggNOG-mapper functional annotation |
| `--enable_ncrna` | Run tRNAscan-SE + Infernal ncRNA annotation |

### Output

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--out_prefix <str>` | out | Output file/directory prefix |
| `--gene_prefix <str>` | gene | Gene ID prefix in GFF3 output |
| `--delete_unimportant_intermediate_files` | off | Clean up large intermediate files after success |

## Output Files

| File | Description |
|------|-------------|
| `{prefix}.geneModels.gff3` | All gene models with alternative splicing |
| `{prefix}.bestGeneModels.gff3` | Best transcript per gene |
| `{prefix}.geneModels.gtf` | GTF format |
| `{prefix}.protein.fasta` | Predicted protein sequences |
| `{prefix}.cds.fasta` | CDS nucleotide sequences |
| `{prefix}.gene_prediction.summary` | Pipeline statistics and quality report |
| `{prefix}.maskedGenome.fasta` | Repeat-masked genome |
| `{prefix}.repeat.gff3` | Repeat annotation |
| `{prefix}.geneModels_lowQuality.gff3` | Low-quality / unvalidated gene models |

## Configuration

Configuration files control tool-specific parameters. GWAP auto-selects based on genome size:

| Genome Size | Config File | Key Differences |
|-------------|-------------|-----------------|
| > 1 GB | `conf_for_big_genome.txt` | Stricter miniprot (`--outs 0.97`), larger max intron (100kb) |
| 50 MB - 1 GB | `conf_all_defaults.txt` | Balanced defaults |
| < 50 MB | `conf_for_small_genome.txt` | More permissive filtering, smaller max intron (4kb) |

Override with `--config your_config.txt`. See `conf_all_defaults.txt` for all available sections:
`[para_RepeatMasker]`, `[homolog_prediction]`, `[Sam2Transfrag]`, `[GFF3_merging_and_removing_redundancy]`, `[BGM2AT]`, `[prepareAugusutusHints]`, `[paraAugusutusWithHints]`, `[pickout_reliable_geneModels]`, `[GFF3_database_validation]`, `[LongReads_prediction]`, `[IsoQuant]`, `[SQANTI3_filter]`, `[miniprothint]`

## How It Works

### Step 1: Repeat Masking
RepeatModeler builds a species-specific repeat library; RepeatMasker masks the genome using Dfam HMMs. For plant genomes, `--TE_annotator edta` uses EDTA for superior LTR retrotransposon detection.

### Step 2: Homolog Prediction
**miniprot** performs splice-aware protein-to-genome alignment in a single pass (replacing the former MMseqs2 + exonerate/genewise/gth two-stage pipeline). Gene models are classified A/B/C/D by protein coverage and identity.

### Step 3: Transcript-Based Prediction
- **Long-read path** (primary): minimap2 aligns FLNC reads; IsoQuant discovers transcripts; SQANTI3 filters artifacts (intra-priming, RT-switching, truncations); TransDecoder predicts ORFs.
- **Short-read path** (optional/fallback): fastp quality control; STAR (or HISAT2) alignment; transcript assembly and ORF prediction.
- **Hybrid mode**: When both are provided, short-read splice junctions are fed to IsoQuant for long-read junction correction.

### Step 4: AUGUSTUS Ab Initio Prediction
High-quality gene models from Steps 2-3 train AUGUSTUS HMM parameters. miniprothint generates confidence-scored protein hints. Parallelized AUGUSTUS prediction with combined hints.

### Step 5: Evidence Integration
The core differentiator: multi-round merging, gap-filling, and filtering.
1. Fill transcript models with homolog evidence
2. Merge with homolog predictions, remove redundancy
3. Fill with AUGUSTUS predictions
4. Force-complete remaining partial models
5. Remove transposon-overlapping genes
6. Classify into reliable vs. needs-validation
7. Validate uncertain models against HMM/BLASTP databases
8. Alternative splicing analysis (enhanced by long-read isoforms when available)

### Step 6: Output
GFF3/GTF files, protein/CDS sequences, quality assessment (compleasm), optional functional annotation (eggNOG-mapper) and ncRNA annotation (tRNAscan-SE + Infernal).

## Long-Read Data Preparation

### PacBio IsoSeq / Kinnex

```bash
# For Kinnex: deconcatenate first
skera split input.hifi.bam mas_adapters.fasta segmented.bam

# Standard IsoSeq processing
lima segmented.bam primers.fasta demuxed.bam --isoseq
isoseq refine demuxed.*.bam primers.fasta flnc.bam --require-polya

# Feed FLNC reads to GWAP
perl bin/geta.pl --genome genome.fa --long_reads flnc.bam \
     --long_read_type pacbio_hifi --protein homolog.fa --cpu 48
```

### Oxford Nanopore cDNA

```bash
# Basecall with dorado
dorado basecaller model input_reads/ > basecalled.bam

# Trim cDNA adapters
pychopper basecalled.fastq trimmed.fastq

# Feed to GWAP
perl bin/geta.pl --genome genome.fa --long_reads trimmed.fastq \
     --long_read_type nanopore_cdna --protein homolog.fa --cpu 48
```

### Oxford Nanopore Direct RNA

```bash
# No adapter trimming needed for direct RNA
perl bin/geta.pl --genome genome.fa --long_reads direct_rna.fastq \
     --long_read_type nanopore_drna --protein homolog.fa --cpu 48
```

## Citation

If you use this pipeline, please cite:

- GETA: Chen et al. [https://github.com/chenlianfu/geta](https://github.com/chenlianfu/geta)
- miniprot: Li H. (2023) Protein-to-genome alignment with miniprot. *Bioinformatics*, 39(1):btad014
- IsoQuant: Prjibelski et al. (2023) Accurate isoform discovery and quantification from long-read sequencing. *Nature Biotechnology*
- SQANTI3: Pardo-Palacios et al. (2024) Systematic assessment of long-read RNA-seq methods for transcript identification and quantification. *Nature Methods*
- AUGUSTUS: Stanke et al. (2006) Gene prediction in eukaryotes with a generalized hidden Markov model. *Bioinformatics*

## License

This project is open source. See individual tool licenses for their respective terms.

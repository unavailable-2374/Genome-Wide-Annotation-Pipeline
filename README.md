# GWAP — Genome-Wide Annotation Pipeline

Fully automated eukaryotic genome annotation. Input a genome, long-read RNA-Seq, and homologous proteins — get accurate gene models in one command.

## Pipeline

```
Genome ──> Step 1: Repeat Masking (RepeatModeler/EDTA + RepeatMasker)
              |
              ├──> Step 2: Homolog Prediction (miniprot)
              |
              ├──> Step 3: Transcript Prediction
              |      Long reads:  minimap2 → IsoQuant → SQANTI3 → TransDecoder
              |      Short reads: fastp → STAR → assembly → ORF (optional)
              |      Hybrid: short-read junctions correct long-read splicing
              |
              ├──> Step 4: AUGUSTUS (training + miniprothint hints + prediction)
              |
              ├──> Step 5: Integration
              |      Fill → Merge → Redundancy removal → TE filtering →
              |      HMM/BLASTP validation → Alternative splicing
              |
              └──> Step 6: Output (GFF3/GTF + proteins + compleasm QC)
```

## Quick Start

```bash
# Long reads + homolog proteins (recommended)
perl bin/geta.pl --genome genome.fa \
     --long_reads flnc.bam --long_read_type pacbio_hifi \
     --protein homolog.fa --cpu 48

# Long reads + short reads assist (best quality)
perl bin/geta.pl --genome genome.fa \
     --long_reads flnc.bam --long_read_type pacbio_hifi \
     --pe1 lib.1.fq.gz --pe2 lib.2.fq.gz \
     --protein homolog.fa --cpu 48

# Short reads only
perl bin/geta.pl --genome genome.fa \
     --pe1 lib.1.fq.gz --pe2 lib.2.fq.gz \
     --protein homolog.fa --cpu 48
```

## Installation

```bash
git clone https://github.com/unavailable-2374/Genome-Wide-Annotation-Pipeline.git
cd Genome-Wide-Annotation-Pipeline
export PATH=$(pwd)/bin:$PATH
```

### Core dependencies

```bash
# Conda/Mamba
mamba install -c bioconda -c conda-forge \
  minimap2 miniprot samtools diamond hmmer \
  augustus repeatmasker repeatmodeler \
  star fastp gffread transdecoder parafly

# Python packages
pip install isoquant compleasm
```

SQANTI3 must be installed separately following [its documentation](https://github.com/ConesaLab/SQANTI3).

Set the AUGUSTUS config path:

```bash
export AUGUSTUS_CONFIG_PATH=/path/to/augustus/config/
```

### Optional dependencies

Install only if you need the corresponding feature:

| Tool | Install | Enabled by |
|------|---------|------------|
| [EDTA](https://github.com/oushujun/EDTA) | `mamba install -c bioconda edta` | `--TE_annotator edta` |
| [miniprothint](https://github.com/tomasbruna/miniprothint) | GitHub clone | auto (when `--protein` provided) |
| [PSAURON](https://github.com/salzberg-lab/PSAURON) | `pip install psauron` | `--enable_psauron` |
| [eggNOG-mapper](https://github.com/eggnogdb/eggnog-mapper) | `mamba install -c bioconda eggnog-mapper` | `--enable_eggnog` |
| [tRNAscan-SE](http://lowelab.ucsc.edu/tRNAscan-SE/) | `mamba install -c bioconda trnascan-se` | `--enable_ncrna` |
| [Infernal](http://eddylab.org/infernal/) | `mamba install -c bioconda infernal` | `--enable_ncrna` |

## Parameters

### Input

| Parameter | Description |
|-----------|-------------|
| `--genome <file>` | **(required)** Genome FASTA |
| `--long_reads <file>` | PacBio FLNC or Nanopore FASTQ/BAM (comma-separated) |
| `--long_read_type <str>` | `pacbio_hifi` (default), `nanopore_cdna`, `nanopore_drna` |
| `--pe1 <file> --pe2 <file>` | Paired-end short-read FASTQ (.gz supported, comma-separated) |
| `--se <file>` | Single-end short-read FASTQ |
| `--sam <file>` | Pre-aligned SAM/BAM |
| `--protein <file>` | Homologous protein FASTA (3-10 species recommended) |
| `--RM_species_Dfam <str>` | Dfam clade for RepeatMasker (e.g. `Viridiplantae`, `Metazoa`) |
| `--RM_lib <file>` | Custom repeat library FASTA |
| `--HMM_db <file>` | Pfam HMM database for gene filtering (comma-separated) |
| `--BUSCO_lineage_dataset <str>` | compleasm lineage name(s) |

At least one of `--long_reads`, `--pe1/--pe2`, `--se`, `--sam`, or `--protein` is required.

### Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--cpu` | 4 | CPU threads |
| `--aligner` | star | Short-read aligner: `star` or `hisat2` |
| `--TE_annotator` | repeatmodeler | `repeatmodeler` or `edta` (plants) |
| `--strand_specific` | off | Strand-specific RNA-Seq |
| `--genetic_code` | 1 | NCBI genetic code table |
| `--optimize_augustus_method` | 3 | 1=fast, 2=thorough, 3=both |
| `--config <file>` | auto | Custom config (auto-selected by genome size) |
| `--no_RepeatModeler` | off | Skip RepeatModeler (pre-masked genome) |
| `--no_alternative_splicing_analysis` | off | Skip AS analysis |
| `--enable_psauron` | off | PSAURON gene model quality scoring |
| `--enable_eggnog` | off | eggNOG-mapper functional annotation |
| `--enable_ncrna` | off | tRNAscan-SE + Infernal ncRNA annotation |
| `--out_prefix` | out | Output file prefix |
| `--gene_prefix` | gene | Gene ID prefix in GFF3 |
| `--delete_unimportant_intermediate_files` | off | Clean up after completion |

## Output Files

| File | Description |
|------|-------------|
| `{prefix}.geneModels.gff3` | Gene models with alternative splicing |
| `{prefix}.bestGeneModels.gff3` | Best transcript per gene |
| `{prefix}.geneModels.gtf` | GTF format |
| `{prefix}.protein.fasta` | Protein sequences |
| `{prefix}.cds.fasta` | CDS sequences |
| `{prefix}.gene_prediction.summary` | Statistics and quality report |
| `{prefix}.maskedGenome.fasta` | Repeat-masked genome |
| `{prefix}.repeat.gff3` | Repeat annotation |
| `{prefix}.geneModels_lowQuality.gff3` | Unvalidated gene models |

## Configuration

Auto-selected by genome size:

| Genome Size | Config | Notes |
|-------------|--------|-------|
| > 1 GB | `conf_for_big_genome.txt` | Stricter filtering, max intron 100kb |
| 50 MB – 1 GB | `conf_all_defaults.txt` | Balanced |
| < 50 MB | `conf_for_small_genome.txt` | Permissive filtering, max intron 4kb |

Override with `--config your_config.txt`. See `conf_all_defaults.txt` for all tunable sections.

## Long-Read Data Preparation

### PacBio IsoSeq / Kinnex

```bash
# Kinnex: deconcatenate first
skera split input.hifi.bam mas_adapters.fasta segmented.bam

# Standard IsoSeq processing
lima segmented.bam primers.fasta demuxed.bam --isoseq
isoseq refine demuxed.*.bam primers.fasta flnc.bam --require-polya

perl bin/geta.pl --genome genome.fa --long_reads flnc.bam \
     --long_read_type pacbio_hifi --protein homolog.fa --cpu 48
```

### Nanopore cDNA

```bash
dorado basecaller model input_reads/ > basecalled.bam
pychopper basecalled.fastq trimmed.fastq

perl bin/geta.pl --genome genome.fa --long_reads trimmed.fastq \
     --long_read_type nanopore_cdna --protein homolog.fa --cpu 48
```

### Nanopore Direct RNA

```bash
perl bin/geta.pl --genome genome.fa --long_reads direct_rna.fastq \
     --long_read_type nanopore_drna --protein homolog.fa --cpu 48
```

## Citation

- GETA: Chen et al. [github.com/chenlianfu/geta](https://github.com/chenlianfu/geta)
- miniprot: Li H. (2023) *Bioinformatics* 39(1):btad014
- IsoQuant: Prjibelski et al. (2023) *Nature Biotechnology*
- SQANTI3: Pardo-Palacios et al. (2024) *Nature Methods*
- AUGUSTUS: Stanke et al. (2006) *Bioinformatics*

## License

Open source. See individual tool licenses for their respective terms.

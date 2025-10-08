# Usage Guide - WES Pipeline

Comprehensive usage instructions and examples for the WES Pipeline.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Input Preparation](#input-preparation)
3. [Execution Modes](#execution-modes)
4. [Advanced Options](#advanced-options)
5. [Output Interpretation](#output-interpretation)
6. [Common Workflows](#common-workflows)

---

## Basic Usage

### Minimal Command

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed
```

### With Common Options

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode cpu \
  --max_cpus 32 \
  --max_memory 128.GB \
  -profile standard \
  -resume
```

---

## Input Preparation

### Option 1: CSV Samplesheet (Recommended)

Create `samples.csv`:

```csv
sample_id,read1,read2
Sample_A,/data/Sample_A_R1.fastq.gz,/data/Sample_A_R2.fastq.gz
Sample_B,/data/Sample_B_R1.fastq.gz,/data/Sample_B_R2.fastq.gz
Sample_C,/data/Sample_C_R1.fastq.gz,/data/Sample_C_R2.fastq.gz
```

**Rules:**
- Header must be: `sample_id,read1,read2`
- Sample IDs must be unique
- File paths can be absolute or relative
- All files must exist

**Run:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed
```

### Option 2: Directory Pattern

Place FASTQ files in a directory:

```
data/
├── Sample_A_R1.fastq.gz
├── Sample_A_R2.fastq.gz
├── Sample_B_R1.fastq.gz
├── Sample_B_R2.fastq.gz
├── Sample_C_R1.fastq.gz
└── Sample_C_R2.fastq.gz
```

**Run:**
```bash
nextflow run main.nf \
  --input_dir data \
  --pattern "*_R{1,2}.fastq.gz" \
  --outdir results \
  --reference hg38 \
  --bed targets.bed
```

### BED File Preparation

Your target BED file should cover exome regions:

```
chr1	12345	67890	target1
chr1	78901	123456	target2
chr2	23456	78901	target3
...
```

**Common exome capture kits:**
- Agilent SureSelect: Available from manufacturer
- Illumina Nextera: Available from manufacturer
- Twist Bioscience: Available from manufacturer

**Tips:**
- Use 0-based coordinates (standard BED format)
- Include header if needed (lines starting with `#`)
- Sort and merge overlapping regions:

```bash
bedtools sort -i targets.bed | bedtools merge > targets_merged.bed
```

---

## Execution Modes

### CPU Mode (Default)

Best for: Standard workstations, cloud instances without GPU

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode cpu \
  --max_cpus 32 \
  --max_memory 128.GB \
  -profile standard
```

**Performance:** 8-12 hours per sample (100M read pairs)

### GPU Mode - Single GPU

Best for: Single GPU workstation, cost-effective cloud instances

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode gpu \
  --max_gpus 1 \
  -profile gpu_single
```

**Performance:** 12-15 hours per sample → **5x faster**

### GPU Mode - Multi-GPU

Best for: High-throughput labs, batch processing

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode gpu \
  --max_gpus 4 \
  --samples_per_gpu 2 \
  -profile gpu_multi
```

**Performance:** Process 8 samples in ~4 hours → **20x faster**

### Hybrid Mode (Recommended)

Best for: Systems with GPUs, optimal resource utilization

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode hybrid \
  --max_gpus 2 \
  --max_cpus 32 \
  -profile hybrid
```

**Performance:** ~3 hours per sample → **26x faster with 4 GPUs**

Uses GPU for:
- Alignment (BWA-MEM2)
- Duplicate marking
- Base recalibration
- Variant calling

Uses CPU for:
- QC (FastQC, MultiQC)
- Metrics collection
- Variant filtering
- Post-processing

---

## Advanced Options

### Reference Genome Options

**Use pre-downloaded reference:**
```bash
nextflow run main.nf \
  --reference_fasta /path/to/hg38.fa \
  --input samples.csv \
  --outdir results \
  --bed targets.bed
```

**Specify known sites manually:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --known_sites_dbsnp /path/to/dbsnp.vcf.gz \
  --known_sites_mills /path/to/mills.vcf.gz \
  --known_sites_1000g /path/to/1000g.vcf.gz
```

### Trimming Options

**Adjust fastp parameters:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --trim_front1 5 \
  --trim_front2 5 \
  --min_length 50 \
  --cut_mean_quality 25
```

### Variant Calling Options

**Generate GVCF for joint calling:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --emit_ref_confidence GVCF \
  --call_conf 20
```

**Adjust hard filters:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --snp_filter_qd 3.0 \
  --snp_filter_fs 50.0 \
  --indel_filter_qd 3.0
```

### Repeat Expansion Analysis

**Include ExpansionHunter:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --run_expansion_hunter true \
  --variant_catalog /path/to/variant_catalog.json
```

**Flag variants in repeat regions:**
```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --repeat_bed /path/to/repeat_regions.bed
```

### Skip Steps

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --skip_qc false \
  --skip_multiqc false \
  --skip_hsmetrics false \
  --skip_expansion_hunter true
```

### Save Intermediate Files

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --save_intermediate true \
  --save_reference true
```

---

## Output Interpretation

### Directory Structure

```
results/
├── qc/
│   ├── raw/fastqc/              # Raw read QC
│   ├── trimmed/fastqc/          # Trimmed read QC
│   └── fastp/                   # Trimming reports
├── alignment/
│   ├── raw_bam/                 # Initial alignments (if saved)
│   ├── deduplicated/            # Final BAM files
│   │   ├── sample1_dedup_recal.bam
│   │   └── sample1_dedup_recal.bam.bai
│   └── cram/                    # Compressed CRAM
│       ├── sample1_final.cram
│       └── sample1_final.cram.crai
├── variants/
│   ├── raw/                     # Unfiltered VCFs
│   ├── filtered/                # Filtered VCFs
│   │   ├── sample1_filtered.vcf.gz
│   │   ├── sample1_snps.vcf.gz
│   │   └── sample1_indels.vcf.gz
│   ├── mitochondria/            # MT variants
│   └── repeats/                 # Repeat expansions
├── metrics/
│   ├── hsmetrics/               # Coverage metrics
│   │   └── sample1_hs_metrics.txt
│   └── duplicates/              # Duplication rates
│       └── sample1_duplicate_metrics.txt
└── reports/
    ├── multiqc_raw.html         # Raw QC report
    ├── multiqc_trimmed.html     # Trimmed QC report
    ├── multiqc_report.html      # Final report
    ├── nextflow_report.html     # Pipeline execution report
    └── nextflow_timeline.html   # Timeline visualization
```

### Key Output Files

**1. Final BAM Files:**
- Location: `results/alignment/deduplicated/`
- Files: `*_dedup_recal.bam` and `*.bai`
- Use for: IGV visualization, further analysis

**2. Filtered Variants:**
- Location: `results/variants/filtered/`
- Files: `*_filtered.vcf.gz`, `*_snps.vcf.gz`, `*_indels.vcf.gz`
- Use for: Annotation, interpretation

**3. Coverage Metrics:**
- Location: `results/metrics/hsmetrics/`
- File: `*_hs_metrics.txt`
- Key metrics:
  - `MEAN_TARGET_COVERAGE`: Average depth
  - `PCT_TARGET_BASES_30X`: Percentage with ≥30x coverage
  - `ON_TARGET_BASES`: Percentage on target

**4. MultiQC Report:**
- Location: `results/reports/multiqc_report.html`
- Contains: Aggregated QC metrics across all samples

### Quality Thresholds

**Good Quality Sample:**
- Mean target coverage: ≥ 100x
- % target bases 30x: ≥ 95%
- Duplication rate: < 20%
- % reads on target: ≥ 70%
- % properly paired: ≥ 95%

**Flags for review:**
- Mean coverage < 50x: May need re-sequencing
- Duplication > 30%: Library quality issue
- % on target < 60%: Capture efficiency problem

---

## Common Workflows

### Workflow 1: Single Sample Analysis

```bash
# 1. Prepare input
cat > sample.csv << EOF
sample_id,read1,read2
patient_001,/data/patient_001_R1.fastq.gz,/data/patient_001_R2.fastq.gz
EOF

# 2. Run pipeline
nextflow run main.nf \
  --input sample.csv \
  --outdir patient_001_results \
  --reference hg38 \
  --bed agilent_v6_targets.bed \
  --compute_mode cpu \
  -profile standard \
  -resume

# 3. Check results
ls -lh patient_001_results/variants/filtered/
```

### Workflow 2: Batch Processing (10 samples)

```bash
# 1. Prepare samplesheet with 10 samples
# 2. Run with multi-GPU
nextflow run main.nf \
  --input batch_samples.csv \
  --outdir batch_results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode gpu \
  --max_gpus 4 \
  --samples_per_gpu 2 \
  -profile gpu_multi \
  -resume

# Expected time: ~4 hours for all 10 samples
```

### Workflow 3: HPC Cluster (SLURM)

```bash
# 1. Create SLURM submission script
cat > run_wes.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=wes_pipeline
#SBATCH --nodes=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --output=wes_%j.log

module load nextflow/23.04.0
module load singularity/3.11.0

nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode cpu \
  -profile slurm,singularity \
  -resume
EOF

# 2. Submit job
sbatch run_wes.slurm
```

### Workflow 4: Cloud (AWS Batch)

```bash
# 1. Configure AWS Batch queue
# 2. Run pipeline
nextflow run main.nf \
  --input s3://my-bucket/samples.csv \
  --outdir s3://my-bucket/results \
  --reference hg38 \
  --bed s3://my-bucket/targets.bed \
  -profile awsbatch \
  -bucket-dir s3://my-bucket/nextflow-work \
  -resume
```

### Workflow 5: Resume Failed Run

```bash
# Pipeline failed at variant calling
# Simply re-run with -resume
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  -resume  # Will skip completed steps
```

---

## Performance Optimization Tips

### 1. Increase Parallelization

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --parallel_chromosomes true \
  --max_cpus 64
```

### 2. Use Hybrid Mode with Multiple GPUs

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode hybrid \
  --max_gpus 4 \
  --samples_per_gpu 2
```

### 3. Optimize Resource Allocation

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  --max_cpus 64 \
  --max_memory 256.GB \
  --max_time 48.h
```

### 4. Use NVMe Storage

```bash
# Set Nextflow work directory to NVMe
export NXF_WORK=/mnt/nvme/work

nextflow run main.nf \
  --input samples.csv \
  --outdir /mnt/nvme/results \
  --reference hg38 \
  --bed targets.bed
```

---

## Monitoring and Debugging

### Monitor Pipeline Progress

```bash
# Terminal 1: Run pipeline
nextflow run main.nf --input samples.csv --outdir results ...

# Terminal 2: Watch GPU usage (if GPU mode)
watch -n 1 nvidia-smi

# Terminal 3: Monitor disk usage
watch -n 5 df -h
```

### Check Logs

```bash
# Nextflow log
cat .nextflow.log

# Process-specific logs
cat work/<hash>/hash/.command.log

# Error logs
grep ERROR .nextflow.log
```

### Debug Mode

```bash
nextflow run main.nf \
  --input samples.csv \
  --outdir results \
  --reference hg38 \
  --bed targets.bed \
  -with-
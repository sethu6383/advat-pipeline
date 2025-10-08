#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
========================================================================================
    WES PIPELINE - Ultra-Fast Whole Exome Sequencing Pipeline
========================================================================================
    Github : https://github.com/your-org/wes-pipeline
    Documentation: https://wes-pipeline.readthedocs.io
----------------------------------------------------------------------------------------
*/

// Print pipeline header
def printHeader() {
    log.info """\
    ==========================================
    WES PIPELINE - v1.0.0
    ==========================================
    Input          : ${params.input}
    Output Dir     : ${params.outdir}
    Reference      : ${params.reference}
    BED File       : ${params.bed}
    Compute Mode   : ${params.compute_mode}
    Max GPUs       : ${params.max_gpus}
    ==========================================
    """.stripIndent()
}

printHeader()

/*
========================================================================================
    IMPORT MODULES
========================================================================================
*/

// Reference setup
include { DOWNLOAD_REFERENCE      } from './modules/reference/download_reference'
include { BUILD_BWA_INDEX         } from './modules/reference/build_bwa_index'
include { DOWNLOAD_KNOWN_SITES    } from './modules/reference/download_known_sites'
include { PREPARE_INTERVALS       } from './modules/reference/prepare_intervals'

// GPU detection and configuration
include { DETECT_GPUS             } from './modules/gpu/detect_gpus'
include { CONFIGURE_GPU_RESOURCES } from './modules/gpu/configure_resources'

// QC modules
include { FASTQC as FASTQC_RAW    } from './modules/qc/fastqc'
include { FASTQC as FASTQC_TRIMMED} from './modules/qc/fastqc'
include { FASTP                   } from './modules/qc/fastp'
include { MULTIQC as MULTIQC_RAW  } from './modules/qc/multiqc'
include { MULTIQC as MULTIQC_TRIMMED } from './modules/qc/multiqc'
include { MULTIQC as MULTIQC_FINAL} from './modules/qc/multiqc'

// Alignment modules - CPU
include { BWA_MEM2_ALIGN          } from './modules/alignment/cpu/bwa_mem2'
include { SAMTOOLS_SORT           } from './modules/alignment/cpu/samtools_sort'
include { SAMBAMBA_MARKDUP        } from './modules/alignment/cpu/sambamba_markdup'

// Alignment modules - GPU
include { PARABRICKS_FQ2BAM       } from './modules/alignment/gpu/parabricks_fq2bam'

// BQSR modules - CPU
include { BASE_RECALIBRATOR       } from './modules/bqsr/cpu/base_recalibrator'
include { APPLY_BQSR              } from './modules/bqsr/cpu/apply_bqsr'

// Variant calling - CPU
include { HAPLOTYPECALLER_CHR     } from './modules/variants/cpu/haplotypecaller'
include { GATHER_VCFS             } from './modules/variants/shared/gather_vcfs'

// Variant calling - GPU
include { PARABRICKS_HAPLOTYPECALLER } from './modules/variants/gpu/parabricks_haplotypecaller'

// Variant processing
include { VARIANT_FILTRATION      } from './modules/variants/shared/variant_filtration'
include { SPLIT_VARIANTS          } from './modules/variants/shared/split_variants'
include { MITOCHONDRIAL_CALLING   } from './modules/variants/shared/mitochondrial_calling'
include { FLAG_REPEAT_VARIANTS    } from './modules/variants/shared/flag_repeats'

// Metrics
include { PICARD_HSMETRICS        } from './modules/metrics/picard_hsmetrics'
include { COLLECT_DUP_METRICS     } from './modules/metrics/collect_dup_metrics'

// Repeat expansion
include { EXPANSION_HUNTER        } from './modules/repeats/expansion_hunter'

// Compression
include { BAM_TO_CRAM             } from './modules/compression/bam_to_cram'

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

// Check mandatory parameters
if (!params.input) {
    exit 1, "Error: --input parameter is required (CSV samplesheet or directory path)"
}

if (!params.outdir) {
    exit 1, "Error: --outdir parameter is required"
}

if (!params.reference && !params.reference_fasta) {
    exit 1, "Error: Either --reference (hg38/hg19) or --reference_fasta must be provided"
}

if (!params.bed) {
    exit 1, "Error: --bed parameter is required (target regions BED file)"
}

/*
========================================================================================
    PARSE INPUT
========================================================================================
*/

workflow PARSE_INPUT {
    main:
    if (params.input.endsWith('.csv')) {
        // CSV samplesheet input
        Channel
            .fromPath(params.input)
            .splitCsv(header: true)
            .map { row ->
                def sample_id = row.sample_id
                def read1 = file(row.read1)
                def read2 = file(row.read2)
                
                if (!read1.exists()) exit 1, "Error: Read 1 file not found: ${read1}"
                if (!read2.exists()) exit 1, "Error: Read 2 file not found: ${read2}"
                
                return tuple(sample_id, read1, read2)
            }
            .set { samples_ch }
    } else {
        // Directory pattern input
        def pattern = params.pattern ?: "*_R{1,2}.fastq.gz"
        Channel
            .fromFilePairs("${params.input}/${pattern}", flat: true)
            .map { sample_id, read1, read2 ->
                return tuple(sample_id, file(read1), file(read2))
            }
            .set { samples_ch }
    }
    
    emit:
    samples = samples_ch
}

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow {
    
    // Parse input samples
    PARSE_INPUT()
    samples_ch = PARSE_INPUT.out.samples
    
    // Count samples for reporting
    samples_ch
        .count()
        .subscribe { count ->
            log.info "Found ${count} samples to process"
        }
    
    /*
    ========================================================================================
        REFERENCE GENOME SETUP
    ========================================================================================
    */
    
    if (params.reference_fasta) {
        // User-provided reference
        reference_fasta = file(params.reference_fasta)
        reference_index = file("${params.reference_fasta}.fai")
        reference_dict = file(params.reference_fasta.replaceAll(/\.fa(sta)?$/, '.dict'))
    } else {
        // Download reference
        DOWNLOAD_REFERENCE(params.reference)
        reference_fasta = DOWNLOAD_REFERENCE.out.fasta
        reference_index = DOWNLOAD_REFERENCE.out.fai
        reference_dict = DOWNLOAD_REFERENCE.out.dict
    }
    
    // Build BWA index if needed
    if (params.compute_mode == 'cpu' || params.compute_mode == 'hybrid') {
        BUILD_BWA_INDEX(reference_fasta)
        bwa_index = BUILD_BWA_INDEX.out.index
    }
    
    // Download known sites for BQSR
    DOWNLOAD_KNOWN_SITES(params.reference)
    known_sites = DOWNLOAD_KNOWN_SITES.out.known_sites
    
    // Prepare intervals for parallel processing
    PREPARE_INTERVALS(
        file(params.bed),
        reference_fasta,
        reference_index
    )
    chromosomes_ch = PREPARE_INTERVALS.out.chromosomes
    intervals_ch = PREPARE_INTERVALS.out.intervals
    
    /*
    ========================================================================================
        GPU CONFIGURATION
    ========================================================================================
    */
    
    if (params.compute_mode == 'gpu' || params.compute_mode == 'hybrid') {
        DETECT_GPUS()
        gpu_config = DETECT_GPUS.out.config
        
        CONFIGURE_GPU_RESOURCES(gpu_config, samples_ch.count())
        gpu_assignments = CONFIGURE_GPU_RESOURCES.out.assignments
    }
    
    /*
    ========================================================================================
        QC - RAW READS
    ========================================================================================
    */
    
    FASTQC_RAW(samples_ch, 'raw')
    
    MULTIQC_RAW(
        FASTQC_RAW.out.zip.collect(),
        'raw',
        "${params.outdir}/reports"
    )
    
    /*
    ========================================================================================
        TRIMMING
    ========================================================================================
    */
    
    FASTP(samples_ch)
    trimmed_reads_ch = FASTP.out.reads
    
    /*
    ========================================================================================
        QC - TRIMMED READS
    ========================================================================================
    */
    
    FASTQC_TRIMMED(trimmed_reads_ch, 'trimmed')
    
    MULTIQC_TRIMMED(
        FASTQC_TRIMMED.out.zip.collect()
            .mix(FASTP.out.json.collect()),
        'trimmed',
        "${params.outdir}/reports"
    )
    
    /*
    ========================================================================================
        ALIGNMENT & PREPROCESSING
    ========================================================================================
    */
    
    if (params.compute_mode == 'cpu') {
        // CPU-based alignment pipeline
        BWA_MEM2_ALIGN(
            trimmed_reads_ch,
            bwa_index,
            reference_fasta
        )
        
        SAMTOOLS_SORT(BWA_MEM2_ALIGN.out.bam)
        
        SAMBAMBA_MARKDUP(SAMTOOLS_SORT.out.sorted_bam)
        dedup_bam_ch = SAMBAMBA_MARKDUP.out.bam
        dup_metrics_ch = SAMBAMBA_MARKDUP.out.metrics
        
        // BQSR
        BASE_RECALIBRATOR(
            dedup_bam_ch,
            reference_fasta,
            reference_index,
            reference_dict,
            known_sites
        )
        
        APPLY_BQSR(
            dedup_bam_ch,
            BASE_RECALIBRATOR.out.recal_table,
            reference_fasta,
            reference_index,
            reference_dict
        )
        
        final_bam_ch = APPLY_BQSR.out.bam
        
    } else if (params.compute_mode == 'gpu') {
        // GPU-based alignment pipeline (includes BQSR)
        
        // Combine samples with GPU assignments
        trimmed_reads_ch
            .combine(gpu_assignments)
            .set { samples_with_gpu }
        
        PARABRICKS_FQ2BAM(
            samples_with_gpu,
            reference_fasta,
            known_sites
        )
        
        final_bam_ch = PARABRICKS_FQ2BAM.out.bam
        dup_metrics_ch = PARABRICKS_FQ2BAM.out.metrics
        
    } else if (params.compute_mode == 'hybrid') {
        // Hybrid mode: GPU for alignment, CPU for other tasks
        
        trimmed_reads_ch
            .combine(gpu_assignments)
            .set { samples_with_gpu }
        
        PARABRICKS_FQ2BAM(
            samples_with_gpu,
            reference_fasta,
            known_sites
        )
        
        final_bam_ch = PARABRICKS_FQ2BAM.out.bam
        dup_metrics_ch = PARABRICKS_FQ2BAM.out.metrics
    }
    
    /*
    ========================================================================================
        METRICS COLLECTION
    ========================================================================================
    */
    
    PICARD_HSMETRICS(
        final_bam_ch,
        reference_fasta,
        reference_index,
        reference_dict,
        file(params.bed)
    )
    
    COLLECT_DUP_METRICS(dup_metrics_ch)
    
    /*
    ========================================================================================
        VARIANT CALLING
    ========================================================================================
    */
    
    if (params.compute_mode == 'cpu') {
        // CPU variant calling - parallel by chromosome
        
        final_bam_ch
            .combine(chromosomes_ch)
            .set { bam_chr_combinations }
        
        HAPLOTYPECALLER_CHR(
            bam_chr_combinations,
            reference_fasta,
            reference_index,
            reference_dict,
            intervals_ch
        )
        
        // Gather VCFs per sample
        HAPLOTYPECALLER_CHR.out.vcf
            .groupTuple()
            .set { vcfs_to_gather }
        
        GATHER_VCFS(
            vcfs_to_gather,
            reference_fasta,
            reference_index,
            reference_dict
        )
        
        raw_vcf_ch = GATHER_VCFS.out.vcf
        
    } else if (params.compute_mode == 'gpu' || params.compute_mode == 'hybrid') {
        // GPU variant calling - parallel by chromosome across GPUs
        
        final_bam_ch
            .combine(chromosomes_ch)
            .combine(gpu_assignments)
            .set { bam_chr_gpu_combinations }
        
        PARABRICKS_HAPLOTYPECALLER(
            bam_chr_gpu_combinations,
            reference_fasta,
            intervals_ch
        )
        
        // Gather VCFs per sample
        PARABRICKS_HAPLOTYPECALLER.out.vcf
            .groupTuple()
            .set { vcfs_to_gather }
        
        GATHER_VCFS(
            vcfs_to_gather,
            reference_fasta,
            reference_index,
            reference_dict
        )
        
        raw_vcf_ch = GATHER_VCFS.out.vcf
    }
    
    /*
    ========================================================================================
        MITOCHONDRIAL VARIANT CALLING
    ========================================================================================
    */
    
    MITOCHONDRIAL_CALLING(
        final_bam_ch,
        reference_fasta,
        reference_index,
        reference_dict
    )
    
    /*
    ========================================================================================
        VARIANT FILTERING
    ========================================================================================
    */
    
    VARIANT_FILTRATION(
        raw_vcf_ch,
        reference_fasta,
        reference_index,
        reference_dict
    )
    
    SPLIT_VARIANTS(
        VARIANT_FILTRATION.out.filtered_vcf,
        reference_fasta,
        reference_index,
        reference_dict
    )
    
    // Flag variants in repeat regions
    if (params.repeat_bed) {
        FLAG_REPEAT_VARIANTS(
            VARIANT_FILTRATION.out.filtered_vcf,
            file(params.repeat_bed)
        )
    }
    
    /*
    ========================================================================================
        REPEAT EXPANSION DETECTION
    ========================================================================================
    */
    
    if (params.run_expansion_hunter) {
        EXPANSION_HUNTER(
            final_bam_ch,
            reference_fasta,
            file(params.variant_catalog)
        )
    }
    
    /*
    ========================================================================================
        COMPRESSION TO CRAM
    ========================================================================================
    */
    
    BAM_TO_CRAM(
        final_bam_ch,
        reference_fasta,
        reference_index
    )
    
    /*
    ========================================================================================
        FINAL MULTIQC REPORT
    ========================================================================================
    */
    
    // Collect all QC outputs
    all_qc_files = Channel.empty()
        .mix(FASTQC_RAW.out.zip)
        .mix(FASTQC_TRIMMED.out.zip)
        .mix(FASTP.out.json)
        .mix(PICARD_HSMETRICS.out.metrics)
        .mix(COLLECT_DUP_METRICS.out.summary)
        .collect()
    
    MULTIQC_FINAL(
        all_qc_files,
        'final',
        "${params.outdir}/reports"
    )
}

/*
========================================================================================
    WORKFLOW COMPLETION
========================================================================================
*/

workflow.onComplete {
    log.info """\
    ==========================================
    Pipeline completed at: ${workflow.complete}
    Execution status: ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Duration: ${workflow.duration}
    ==========================================
    Results are in: ${params.outdir}
    """.stripIndent()
}

workflow.onError {
    log.error "Pipeline execution stopped with error: ${workflow.errorMessage}"
}
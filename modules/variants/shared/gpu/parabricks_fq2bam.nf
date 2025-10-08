process PARABRICKS_FQ2BAM {
    tag "$sample_id"
    label 'gpu_process'
    
    publishDir "${params.outdir}/alignment/deduplicated", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(read1), path(read2), val(gpu_id)
    path reference
    path known_sites
    
    output:
    tuple val(sample_id), path("${sample_id}_dedup_recal.bam"), path("${sample_id}_dedup_recal.bam.bai"), emit: bam
    path "${sample_id}_bqsr_report.txt", emit: bqsr_report
    path "${sample_id}_duplicate_metrics.txt", emit: metrics
    
    script:
    def license_opt = params.parabricks_license ? "--license-file ${params.parabricks_license}" : ""
    def known_sites_args = known_sites.collect { "--knownSites $it" }.join(' ')
    """
    # Set GPU device
    export CUDA_VISIBLE_DEVICES=${gpu_id}
    
    # Create temp directory
    mkdir -p ${params.parabricks_tmp_dir}/${sample_id}
    
    # Run Parabricks fq2bam (combines alignment, sorting, marking duplicates, and BQSR)
    pbrun fq2bam \\
        --ref ${reference} \\
        --in-fq ${read1} ${read2} \\
        --out-bam ${sample_id}_dedup_recal.bam \\
        ${known_sites_args} \\
        --out-recal-file ${sample_id}_bqsr_report.txt \\
        --out-duplicate-metrics ${sample_id}_duplicate_metrics.txt \\
        --read-group-sm ${sample_id} \\
        --read-group-pl ILLUMINA \\
        --read-group-id ${sample_id} \\
        --read-group-lb ${sample_id}_lib \\
        --num-gpus 1 \\
        --gpu-devices ${gpu_id} \\
        --tmp-dir ${params.parabricks_tmp_dir}/${sample_id} \\
        --num-cpu-threads ${task.cpus} \\
        --bwa-options="-K 100000000 -Y" \\
        ${license_opt}
    
    # Cleanup temp directory
    rm -rf ${params.parabricks_tmp_dir}/${sample_id}
    """
}
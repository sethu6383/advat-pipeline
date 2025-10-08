process PICARD_HSMETRICS {
    tag "$sample_id"
    label 'medium_cpu'
    
    publishDir "${params.outdir}/metrics/hsmetrics", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    path reference_index
    path reference_dict
    path bed
    
    output:
    path "${sample_id}_hs_metrics.txt", emit: metrics
    path "${sample_id}_per_target_coverage.txt", emit: per_target
    
    when:
    !params.skip_hsmetrics
    
    script:
    """
    # Convert BED to interval list
    gatk BedToIntervalList \\
        -I ${bed} \\
        -O targets.interval_list \\
        -SD ${reference_dict}
    
    # Calculate HS metrics
    gatk CollectHsMetrics \\
        -I ${bam} \\
        -R ${reference} \\
        -BAIT_INTERVALS targets.interval_list \\
        -TARGET_INTERVALS targets.interval_list \\
        -O ${sample_id}_hs_metrics.txt \\
        -PER_TARGET_COVERAGE ${sample_id}_per_target_coverage.txt \\
        --COVERAGE_CAP 50000 \\
        --java-options "-Xmx${task.memory.toGiga()}g"
    """
}
process BASE_RECALIBRATOR {
    tag "$sample_id"
    label 'high_cpu'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    path reference_index
    path reference_dict
    path known_sites
    
    output:
    tuple val(sample_id), path("${sample_id}_recal_data.table"), emit: recal_table
    
    script:
    def known_sites_args = known_sites.collect { "--known-sites $it" }.join(' ')
    """
    gatk BaseRecalibrator \\
        -R ${reference} \\
        -I ${bam} \\
        ${known_sites_args} \\
        -O ${sample_id}_recal_data.table \\
        --java-options "-Xmx${task.memory.toGiga()}g -XX:+UseParallelGC -XX:ParallelGCThreads=${task.cpus}"
    """
}
process MITOCHONDRIAL_CALLING {
    tag "$sample_id"
    label 'medium_cpu'
    
    publishDir "${params.outdir}/variants/mitochondria", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    path reference_index
    path reference_dict
    
    output:
    tuple val(sample_id), path("${sample_id}_mito.vcf.gz"), path("${sample_id}_mito.vcf.gz.tbi"), emit: vcf
    path "${sample_id}_mito_stats.txt", emit: stats
    
    script:
    """
    # Call variants on mitochondrial chromosome with higher ploidy
    gatk HaplotypeCaller \\
        -R ${reference} \\
        -I ${bam} \\
        -L chrM -L MT \\
        -O ${sample_id}_mito.vcf.gz \\
        --sample-ploidy 100 \\
        --native-pair-hmm-threads ${task.cpus} \\
        --java-options "-Xmx${task.memory.toGiga()}g"
    
    tabix -p vcf ${sample_id}_mito.vcf.gz
    
    # Generate statistics
    bcftools stats ${sample_id}_mito.vcf.gz > ${sample_id}_mito_stats.txt
    """
}
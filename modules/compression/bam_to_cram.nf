process BAM_TO_CRAM {
    tag "$sample_id"
    label 'high_cpu'
    
    publishDir "${params.outdir}/alignment/cram", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    path reference_index
    
    output:
    tuple val(sample_id), path("${sample_id}_final.cram"), path("${sample_id}_final.cram.crai"), emit: cram
    path "${sample_id}_final.cram.md5", emit: md5
    
    script:
    """
    # Convert BAM to CRAM
    samtools view \\
        -@ ${task.cpus} \\
        -C \\
        -T ${reference} \\
        -o ${sample_id}_final.cram \\
        ${bam}
    
    # Index CRAM
    samtools index \\
        -@ ${task.cpus} \\
        ${sample_id}_final.cram
    
    # Generate MD5 checksum
    md5sum ${sample_id}_final.cram > ${sample_id}_final.cram.md5
    """
}
process FASTQC {
    tag "$sample_id"
    label 'medium_cpu'
    
    publishDir "${params.outdir}/qc/${stage}/fastqc", mode: params.publish_dir_mode
    
    input:
    tuple val(sample_id), path(read1), path(read2)
    val stage  // 'raw' or 'trimmed'
    
    output:
    tuple val(sample_id), path("*.html"), emit: html
    tuple val(sample_id), path("*.zip"), emit: zip
    
    when:
    !params.skip_qc
    
    script:
    """
    fastqc \\
        --quiet \\
        --threads ${task.cpus} \\
        --outdir . \\
        ${read1} ${read2}
    """
}
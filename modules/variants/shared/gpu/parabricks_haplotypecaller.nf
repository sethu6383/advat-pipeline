process PARABRICKS_HAPLOTYPECALLER {
    tag "$sample_id - $chromosome"
    label 'gpu_variant_calling'
    
    input:
    tuple val(sample_id), path(bam), path(bai), val(chromosome), val(gpu_id)
    path reference
    path intervals
    
    output:
    tuple val(sample_id), path("${sample_id}.${chromosome}.vcf.gz"), path("${sample_id}.${chromosome}.vcf.gz.tbi"), emit: vcf
    
    script:
    def interval_arg = intervals ? "--interval-file ${intervals}/${chromosome}.interval_list" : "--interval-file ${chromosome}"
    def license_opt = params.parabricks_license ? "--license-file ${params.parabricks_license}" : ""
    def emit_conf = params.emit_ref_confidence != 'NONE' ? "-ERC ${params.emit_ref_confidence}" : ""
    """
    # Set GPU device
    export CUDA_VISIBLE_DEVICES=${gpu_id}
    
    pbrun haplotypecaller \\
        --ref ${reference} \\
        --in-bam ${bam} \\
        --out-variants ${sample_id}.${chromosome}.vcf.gz \\
        ${interval_arg} \\
        --num-gpus 1 \\
        --gpu-devices ${gpu_id} \\
        --num-cpu-threads ${task.cpus} \\
        ${emit_conf} \\
        ${license_opt}
    
    # Index the VCF
    tabix -p vcf ${sample_id}.${chromosome}.vcf.gz
    """
}
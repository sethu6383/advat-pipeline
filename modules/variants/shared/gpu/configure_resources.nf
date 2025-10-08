process CONFIGURE_GPU_RESOURCES {
    label 'low_cpu'
    
    input:
    path gpu_config
    val num_samples
    
    output:
    path 'gpu_assignments.txt', emit: assignments
    
    script:
    """
    #!/usr/bin/env python3
    import json
    import sys
    
    # Load GPU configuration
    with open('${gpu_config}', 'r') as f:
        config = json.load(f)
    
    num_gpus = config['num_gpus']
    num_samples = ${num_samples}
    samples_per_gpu = config['samples_per_gpu']
    
    if num_gpus == 0:
        print("ERROR: No GPUs available but GPU mode requested", file=sys.stderr)
        sys.exit(1)
    
    # Create GPU assignments for samples
    assignments = []
    
    # Strategy: Round-robin assignment of samples to GPUs
    for sample_idx in range(num_samples):
        gpu_idx = sample_idx % num_gpus
        assignments.append(gpu_idx)
    
    # Write assignments
    with open('gpu_assignments.txt', 'w') as f:
        for gpu_id in assignments:
            f.write(f"{gpu_id}\\n")
    
    print(f"Assigned {num_samples} samples across {num_gpus} GPUs", file=sys.stderr)
    print(f"GPU assignment strategy: Round-robin", file=sys.stderr)
    """
}
process DETECT_GPUS {
    label 'low_cpu'
    
    output:
    path 'gpu_config.json', emit: config
    
    script:
    """
    #!/usr/bin/env python3
    import subprocess
    import json
    import sys
    
    def detect_gpus():
        try:
            # Run nvidia-smi to detect GPUs
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=index,name,memory.total,compute_cap',
                 '--format=csv,noheader,nounits'],
                capture_output=True,
                text=True,
                check=True
            )
            
            gpus = []
            for line in result.stdout.strip().split('\\n'):
                if line:
                    parts = [p.strip() for p in line.split(',')]
                    idx, name, memory, compute_cap = parts
                    gpus.append({
                        'index': int(idx),
                        'name': name,
                        'memory_gb': int(float(memory)) // 1024,
                        'compute_capability': compute_cap
                    })
            
            # Filter GPUs based on user specification
            if ${params.gpu_devices}:
                specified_gpus = [int(x) for x in "${params.gpu_devices}".split(',')]
                gpus = [g for g in gpus if g['index'] in specified_gpus]
            
            # Limit to max_gpus
            max_gpus = ${params.max_gpus}
            if len(gpus) > max_gpus:
                gpus = gpus[:max_gpus]
            
            config = {
                'num_gpus': len(gpus),
                'gpus': gpus,
                'parallel_strategy': 'multi_gpu' if len(gpus) > 1 else 'single_gpu',
                'samples_per_gpu': ${params.samples_per_gpu},
                'cuda_streams': ${params.cuda_streams}
            }
            
            print(f"Detected {len(gpus)} GPU(s) for processing", file=sys.stderr)
            for gpu in gpus:
                print(f"  GPU {gpu['index']}: {gpu['name']} ({gpu['memory_gb']} GB)", file=sys.stderr)
        
        except FileNotFoundError:
            print("WARNING: nvidia-smi not found. No GPUs detected.", file=sys.stderr)
            config = {
                'num_gpus': 0,
                'gpus': [],
                'parallel_strategy': 'cpu_only',
                'samples_per_gpu': 0,
                'cuda_streams': 0
            }
        
        except subprocess.CalledProcessError as e:
            print(f"WARNING: Error running nvidia-smi: {e}", file=sys.stderr)
            config = {
                'num_gpus': 0,
                'gpus': [],
                'parallel_strategy': 'cpu_only',
                'samples_per_gpu': 0,
                'cuda_streams': 0
            }
        
        return config
    
    # Detect GPUs
    gpu_config = detect_gpus()
    
    # Write config to file
    with open('gpu_config.json', 'w') as f:
        json.dump(gpu_config, f, indent=2)
    
    print("GPU configuration saved to gpu_config.json", file=sys.stderr)
    """
}
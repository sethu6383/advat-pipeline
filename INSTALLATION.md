# Installation Guide - WES Pipeline

Complete installation instructions for the WES Pipeline on different systems.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Prerequisites](#prerequisites)
3. [Installation Methods](#installation-methods)
4. [GPU Setup](#gpu-setup)
5. [Reference Genome Setup](#reference-genome-setup)
6. [Validation](#validation)

---

## System Requirements

### Minimum Requirements (CPU Mode)

- **OS**: Linux (Ubuntu 20.04+, CentOS 7+, or similar)
- **CPU**: 16 cores
- **RAM**: 64 GB
- **Storage**: 500 GB (for reference + results)
- **Software**: Docker or Singularity

### Recommended Requirements (GPU Mode)

- **OS**: Linux (Ubuntu 22.04)
- **CPU**: 32+ cores
- **RAM**: 128 GB
- **GPU**: NVIDIA GPU with 16+ GB memory (A100/V100 recommended)
- **Storage**: 1 TB NVMe SSD
- **CUDA**: 12.0+
- **NVIDIA Driver**: 525+

---

## Prerequisites

### 1. Install Docker

**Ubuntu/Debian:**
```bash
# Update package index
sudo apt-get update

# Install dependencies
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
```

**CentOS/RHEL:**
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 2. Install Nextflow

```bash
# Install Java (required)
sudo apt-get install -y openjdk-17-jdk

# Download Nextflow
curl -s https://get.nextflow.io | bash

# Move to system path
sudo mv nextflow /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/nextflow

# Verify installation
nextflow -version
```

### 3. Install Git

```bash
sudo apt-get install -y git
```

---

## Installation Methods

### Method 1: Clone Repository (Recommended)

```bash
# Clone the repository
git clone https://github.com/your-org/wes-pipeline.git
cd wes-pipeline

# Build Docker images
docker build -f docker/Dockerfile.cpu -t wes-pipeline:cpu docker/
docker build -f docker/Dockerfile.gpu -t wes-pipeline:gpu docker/

# Verify images
docker images | grep wes-pipeline
```

### Method 2: Docker Compose Installation

```bash
# Clone repository
git clone https://github.com/your-org/wes-pipeline.git
cd wes-pipeline/docker

# Build all services
docker-compose build

# Verify
docker-compose config
```

### Method 3: Singularity Installation

```bash
# Install Singularity (Ubuntu)
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup

# Install Go
wget https://go.dev/dl/go1.20.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.20.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install Singularity
export VERSION=3.11.0
wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-ce-${VERSION}.tar.gz
tar -xzf singularity-ce-${VERSION}.tar.gz
cd singularity-ce-${VERSION}
./mconfig
make -C builddir
sudo make -C builddir install

# Build Singularity image
cd wes-pipeline
singularity build wes-pipeline-cpu.sif docker://wes-pipeline:cpu
```

---

## GPU Setup

### 1. Install NVIDIA Drivers

```bash
# Check if NVIDIA GPU is detected
lspci | grep -i nvidia

# Install drivers (Ubuntu)
sudo apt-get update
sudo apt-get install -y nvidia-driver-525

# Reboot
sudo reboot

# Verify installation
nvidia-smi
```

### 2. Install NVIDIA Docker Runtime

```bash
# Add NVIDIA package repositories
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
    sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Install nvidia-docker2
sudo apt-get update
sudo apt-get install -y nvidia-docker2

# Restart Docker daemon
sudo systemctl restart docker

# Test GPU access in Docker
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### 3. Install CUDA Toolkit (Optional, for development)

```bash
# Download CUDA 12.2
wget https://developer.download.nvidia.com/compute/cuda/12.2.0/local_installers/cuda_12.2.0_535.54.03_linux.run

# Install
sudo sh cuda_12.2.0_535.54.03_linux.run

# Add to PATH
echo 'export PATH=/usr/local/cuda-12.2/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.2/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Verify
nvcc --version
```

### 4. Install Parabricks (GPU Acceleration)

```bash
# Register at NVIDIA Clara Parabricks
# https://www.nvidia.com/en-us/clara/genomics/

# Download Parabricks (example for version 4.2.0)
# After registration, download the tarball

tar -xzf parabricks_4.2.0.tar.gz -C /opt/
export PATH=/opt/parabricks:$PATH

# Verify installation
pbrun version

# Alternative: Free version (limited features)
# Clara Parabricks free version available through NGC container registry
docker pull nvcr.io/nvidia/clara/clara-parabricks:4.2.0-1
```

---

## Reference Genome Setup

### Automatic Download (Recommended)

The pipeline will automatically download reference genomes on first run:

```bash
# Create reference directory
mkdir -p reference

# Run pipeline - it will download hg38 automatically
nextflow run main.nf \
  --reference hg38 \
  --reference_dir ./reference \
  ... [other parameters]
```

### Manual Download

**hg38 (GRCh38):**
```bash
mkdir -p reference/hg38
cd reference/hg38

# Download reference genome
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
gunzip GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
mv GCA_000001405.15_GRCh38_no_alt_analysis_set.fna hg38.fa

# Create index
samtools faidx hg38.fa

# Create dictionary
gatk CreateSequenceDictionary -R hg38.fa -O hg38.dict

# Download known sites for BQSR
mkdir -p known_sites
cd known_sites

# dbSNP
wget https://ftp.ncbi.nih.gov/snp/organisms/human_9606_b151_GRCh38p7/VCF/GATK/All_20180418.vcf.gz
wget https://ftp.ncbi.nih.gov/snp/organisms/human_9606_b151_GRCh38p7/VCF/GATK/All_20180418.vcf.gz.tbi

# Mills indels
wget https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
wget https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi

# 1000G phase1
wget https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz
wget https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi

cd ../../..
```

**ExpansionHunter Catalog:**
```bash
mkdir -p reference/expansion_hunter
cd reference/expansion_hunter

# Download repeat catalog
wget https://github.com/Illumina/RepeatCatalogs/raw/master/hg38/variant_catalog.json

cd ../..
```

---

## Validation

### 1. Test Docker Installation

```bash
# CPU image
docker run --rm wes-pipeline:cpu bash -c "fastqc --version && bwa-mem2 version && gatk --version"

# GPU image
docker run --rm --gpus all wes-pipeline:gpu bash -c "nvidia-smi && pbrun version"
```

### 2. Test Pipeline with Small Dataset

```bash
# Download test data (chromosome 22 subset)
mkdir -p test_data
cd test_data

# Download sample FASTQ files (example)
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR194/ERR194147/ERR194147_1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR194/ERR194147/ERR194147_2.fastq.gz

# Create samplesheet
cat > samples.csv << EOF
sample_id,read1,read2
test_sample,test_data/ERR194147_1.fastq.gz,test_data/ERR194147_2.fastq.gz
EOF

# Create minimal BED file (chr22 region)
cat > test_targets.bed << EOF
chr22	16000000	17000000
chr22	20000000	21000000
EOF

# Run pipeline
nextflow run main.nf \
  --input samples.csv \
  --outdir test_results \
  --reference hg38 \
  --bed test_targets.bed \
  --compute_mode cpu \
  -profile standard \
  -resume

# Check results
ls -lh test_results/
```

### 3. Verify GPU Acceleration

```bash
# Check GPU usage during pipeline run
watch -n 1 nvidia-smi

# Run benchmark
nextflow run main.nf \
  --input samples.csv \
  --outdir gpu_test_results \
  --reference hg38 \
  --bed targets.bed \
  --compute_mode gpu \
  --max_gpus 1 \
  -profile gpu_single \
  -with-timeline gpu_timeline.html
```

---

## Troubleshooting

### Issue: Docker permission denied

```bash
sudo usermod -aG docker $USER
newgrp docker
# Or logout and login again
```

### Issue: NVIDIA Docker not working

```bash
# Check Docker daemon configuration
sudo cat /etc/docker/daemon.json

# Should contain:
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}

# Restart Docker
sudo systemctl restart docker
```

### Issue: Out of disk space

```bash
# Clean Docker cache
docker system prune -a

# Clean Nextflow work directory
rm -rf work/

# Check disk usage
df -h
du -sh reference/ results/ work/
```

### Issue: Java version conflicts

```bash
# Check Java version
java -version

# Should be Java 17 or higher
# If not, install correct version:
sudo apt-get install -y openjdk-17-jdk
sudo update-alternatives --config java
```

---

## Next Steps

After successful installation:

1. Prepare your input data (samplesheet or directory)
2. Obtain target BED file for your exome capture kit
3. Review [README.md](README.md) for usage instructions
4. Check [USAGE.md](USAGE.md) for detailed examples
5. Run the pipeline!

---


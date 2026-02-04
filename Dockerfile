FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# ---- System deps (build + common runtime deps) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    bzip2 \
    build-essential \
    cmake \
    pkg-config \
    ninja-build \
    python3-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# ---- Miniconda (Python 3.10 capable) ----
ENV CONDA_DIR=/opt/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-py310_24.3.0-0-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniconda.sh
ENV PATH=${CONDA_DIR}/bin:$PATH

# Use bash so we can conda activate
SHELL ["/bin/bash", "-lc"]

# Faster solver + cleanup
RUN conda install -y -n base conda-libmamba-solver && \
    conda config --set solver libmamba && \
    conda clean -afy

WORKDIR /workspace

# Copy env spec first for better caching
COPY environment.yml /workspace/environment.yml

# Create the environment exactly as specified
RUN conda env create -f /workspace/environment.yml && conda clean -afy

# Make the env auto-activate for interactive shells
RUN echo "source activate mega_sam" >> /etc/bash.bashrc

# ---- Install xformers prebuilt for py310 + cu11.8 + pyt2.0.1 ----
RUN source activate mega_sam && \
    wget -q \
      https://anaconda.org/xformers/xformers/0.0.22.post7/download/linux-64/xformers-0.0.22.post7-py310_cu11.8.0_pyt2.0.1.tar.bz2 \
      -O /tmp/xformers.tar.bz2 && \
    conda install -y /tmp/xformers.tar.bz2 && \
    rm -f /tmp/xformers.tar.bz2 && \
    conda clean -afy

# Copy the rest of the repo
COPY . /workspace

# ---- Compile/install camera tracking extensions ----
RUN source activate mega_sam && \
    cd /workspace/base && \
    python setup.py install

CMD ["/bin/bash"]

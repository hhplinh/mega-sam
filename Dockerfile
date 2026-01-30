# syntax=docker/dockerfile:1
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl ca-certificates bzip2 \
    build-essential cmake pkg-config \
    ffmpeg \
    libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# micromamba
ARG MAMBA_VERSION=1.5.10
RUN curl -Ls "https://micro.mamba.pm/api/micromamba/linux-64/${MAMBA_VERSION}" -o /tmp/micromamba.tar.bz2 \
    && mkdir -p /opt/micromamba \
    && tar -xvjf /tmp/micromamba.tar.bz2 -C /opt/micromamba --strip-components=1 bin/micromamba \
    && ln -s /opt/micromamba/micromamba /usr/local/bin/micromamba \
    && rm -f /tmp/micromamba.tar.bz2

ENV MAMBA_ROOT_PREFIX=/opt/conda
RUN micromamba shell init -s bash -p ${MAMBA_ROOT_PREFIX}

WORKDIR /workspace/megasam
COPY . /workspace/megasam

ARG ENV_NAME=mega_sam
RUN micromamba env create -n ${ENV_NAME} -f environment.yml \
    && micromamba clean -a -y

ENV CONDA_DEFAULT_ENV=${ENV_NAME}
ENV PATH=${MAMBA_ROOT_PREFIX}/envs/${ENV_NAME}/bin:$PATH

# torch-scatter: install matching prebuilt wheel for torch 2.0.1 + cu118
RUN micromamba run -n ${ENV_NAME} pip uninstall -y torch-scatter || true
RUN micromamba run -n ${ENV_NAME} pip install \
    torch-scatter==2.1.2 \
    -f https://data.pyg.org/whl/torch-2.0.1+cu118.html

# xformers (optional)
RUN micromamba run -n ${ENV_NAME} python -c "import xformers" 2>/dev/null || \
    (micromamba run -n ${ENV_NAME} micromamba install -y -c xformers -c pytorch -c conda-forge "xformers=0.0.22.post7" || true)

# compile camera tracking module extensions
RUN micromamba run -n ${ENV_NAME} bash -lc "cd base && python setup.py install"

CMD ["bash", "-lc", "python -c \"import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'available', torch.cuda.is_available())\" && bash"]

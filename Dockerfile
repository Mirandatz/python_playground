FROM nvidia/cuda:11.2.2-cudnn8-devel-ubuntu20.04 AS base

# configure env vars
ENV TZ=America/Sao_Paulo
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# install basoc system deps
FROM base as with_system_deps
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    curl git graphviz libgl1 unzip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# install python deps
FROM with_system_deps as with_python_deps
ARG PYTHON_VERSION
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    build-essential gdb lcov pkg-config libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
    libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev lzma lzma-dev tk-dev uuid-dev zlib1g-dev \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# create user
FROM with_python_deps as with_user
ARG UNAME
ARG UID
ARG GID
RUN groupadd --gid $GID $UNAME
RUN useradd --create-home --uid $UID --gid $GID --shell /bin/bash $UNAME
USER $UNAME

# install pyenv and compile python
FROM with_user as with_python
ARG PYTHON_VERSION
ENV PYENV_ROOT /home/$UNAME/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH
SHELL ["/bin/bash", "-c"]
RUN curl https://pyenv.run | bash
RUN pyenv update \
    && PYTHON_CFLAGS="-march=native" \
    CONFIGURE_OPTS="--enable-optimizations --with-lto" \
    pyenv install $PYTHON_VERSION \
    && pyenv global $PYTHON_VERSION

# install tensorflow before other requirements to optimize layer cache
FROM with_python as with_tensorflow
RUN pip install --upgrade pip \
    && pip install tensorflow_datasets tensorflow==2.8.* tensorflow_addons

# install other requirements
FROM with_tensorflow
COPY ./requirements /app/requirements
RUN pip install --upgrade pip \
    && pip install -r /app/requirements/dev.txt --no-cache-dir

# silence tensorflow
ENV TF_CPP_MIN_LOG_LEVEL=1

# enable xla
ENV TF_XLA_FLAGS="--tf_xla_auto_jit=2 --tf_xla_cpu_global_jit"

# be nice with friends and share gpu ram
ENV TF_FORCE_GPU_ALLOW_GROWTH="true"

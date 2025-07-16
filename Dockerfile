ARG UBUNTU_VERSION=22.04
ARG NVIDIA_CUDA_VERSION=11.8.0
ARG CUDA_ARCHITECTURES="90;89;86;80;75;70;61"

FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder
ARG CUDA_ARCHITECTURES
ARG NVIDIA_CUDA_VERSION
ARG UBUNTU_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_XCB_GL_INTEGRATION=xcb_egl
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        git \
        wget \
        ninja-build \
        build-essential \
        libboost-program-options-dev \
        libboost-filesystem-dev \
        libboost-graph-dev \
        libboost-system-dev \
        libeigen3-dev \
        libflann-dev \
        libfreeimage-dev \
        libmetis-dev \
        libgoogle-glog-dev \
        libgtest-dev \
        libsqlite3-dev \
        libglew-dev \
        qtbase5-dev \
        libqt5opengl5-dev \
        libcgal-dev \
        libceres-dev \
        python3.10-dev \
        python3-pip

# Build and install CMake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.31.3/cmake-3.31.3-linux-x86_64.sh \
    -q -O /tmp/cmake-install.sh \
    && chmod u+x /tmp/cmake-install.sh \
    && mkdir /opt/cmake-3.31.3 \
    && /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake-3.31.3 \
    && rm /tmp/cmake-install.sh \
    && ln -s /opt/cmake-3.31.3/bin/* /usr/local/bin

# Build and install COLMAP.
RUN git clone https://github.com/colmap/colmap.git && \
    cd colmap && \
    git checkout "3.12.3" && \
    mkdir build && \
    cd build && \
    mkdir -p /build && \
    cmake .. -GNinja "-DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}" \
        -DCMAKE_INSTALL_PREFIX=/build/colmap && \
    ninja install -j1 && \
    cd ~

# Fix permissions
RUN chmod -R go=u /build

FROM ghcr.io/nerfstudio-project/nerfstudio:main

RUN apt update && apt upgrade -y && apt install -y python3-pip git wget libcurl4

WORKDIR /opt

RUN git clone https://github.com/KevinXu02/splatfacto-w.git && \
    pip3 install -e splatfacto-w

RUN git clone --recursive https://github.com/cvg/Hierarchical-Localization && \
    pip3 install -e Hierarchical-Localization

RUN wget https://demuc.de/colmap/vocab_tree_flickr100K_words32K.bin -O /opt/vocab_tree_flickr100K_words32K.bin


RUN pip3 uninstall nerfstudio -y

RUN echo "downloading latest custom nerfstudio" && git clone https://github.com/Jourdelune/nerfstudio.git && \
    cd nerfstudio && \
    pip3 install --upgrade pip setuptools && \
    pip3 install .

RUN ns-install-cli --mode install

COPY --from=builder /build/colmap/ /usr/local/

CMD ["/bin/bash", "-l"]

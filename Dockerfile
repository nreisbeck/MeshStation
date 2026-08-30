# MeshStation headless — serves the GUI to a browser (MESHSTATION_WEB mode).
#
# The SDR engine is the same conda-packed runtime (GNU Radio 3.10 +
# gr-lora_sdr + gr-osmosdr) that ships with official releases, downloaded per
# architecture. No USB passthrough is required if you use a networked SDR:
# set MESHSTATION_DEVICE_ARGS, e.g. rtl_tcp=my-pi:1234.
#
#   docker compose up -d       ->  http://localhost:8080

FROM condaforge/miniforge3:25.3.1-0

# Release whose engine runtime to reuse (see releases page for versions)
ARG ENGINE_RELEASE=1.1.1
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates tini \
      libx11-6 libxext6 libxrender1 libxft2 \
 && rm -rf /var/lib/apt/lists/*

# Python 3.10 to match what MeshStation is developed against; conda's python
# bundles tkinter (imported at module level even in web mode)
RUN conda install -y python=3.10 tk && conda clean -afy

WORKDIR /app
COPY . /app

# Engine runtime from the official release tarball for this architecture
RUN case "${TARGETARCH:-arm64}" in \
      arm64)  MS_ARCH=linux_aarch64 ;; \
      amd64)  MS_ARCH=linux_x86_64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl -fL -o /tmp/ms.tar.gz \
      "https://github.com/IronGiu/MeshStation/releases/download/v${ENGINE_RELEASE}/MeshStation_${ENGINE_RELEASE}_${MS_ARCH}.tar.gz" \
 && tar -xzf /tmp/ms.tar.gz -C /tmp "engine/os/${MS_ARCH}/runtime" \
 && mkdir -p /app/engine/os \
 && rm -rf "/app/engine/os/${MS_ARCH}" \
 && mv "/tmp/engine/os/${MS_ARCH}" /app/engine/os/ \
 && rm -rf /tmp/ms.tar.gz /tmp/engine

# GUI dependencies (upstream requirements.txt minus the PySide6/qtpy stack,
# which only backs the native Linux window — not used in web mode)
RUN pip install --no-cache-dir \
      nicegui==3.6.1 \
      pyzmq==27.1.0 \
      cryptography==46.0.3 \
      meshtastic==2.7.6 \
      protobuf==6.33.4 \
      pywebview==6.1 \
      cffi==2.0.0

ENV MESHSTATION_WEB=1 \
    MESHSTATION_PORT=8080

# Settings, autosave, and node DB live here
VOLUME /app/data
EXPOSE 8080

ENTRYPOINT ["tini", "--"]
CMD ["python", "/app/MeshStation.py"]

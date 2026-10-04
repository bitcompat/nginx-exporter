# syntax=docker/dockerfile:1.27

ARG BUILD_VERSION=0.11.0

FROM golang:1.24-trixie AS golang-builder

ARG PACKAGE=nginx-prometheus-exporter
ARG TARGET_DIR=nginx-exporter
# renovate: datasource=github-releases depName=nginxinc/nginx-prometheus-exporter
ARG BUILD_VERSION
ARG REF=v${BUILD_VERSION}
ARG CGO_ENABLED=0

ARG TARGETARCH

WORKDIR /go/src/github.com/nginxinc/nginx-prometheus-exporter

COPY --link prebuildfs /
RUN mkdir -p /opt/bitnami
RUN --mount=type=cache,target=/root/.cache/go-build <<EOT /bin/bash
    set -ex

    rm -rf ${PACKAGE} || true
    mkdir -p ${PACKAGE}
    git clone -b "${REF}" https://github.com/nginxinc/nginx-prometheus-exporter ${PACKAGE}

    pushd ${PACKAGE}
    go mod download
    GOOS=linux GOARCH=$TARGETARCH go build -trimpath -a -ldflags "-s -w -X main.version=${BUILD_VERSION}" -o nginx-prometheus-exporter .

    mkdir -p /opt/bitnami/${TARGET_DIR}/licenses
    mkdir -p /opt/bitnami/${TARGET_DIR}/bin
    cp -f LICENSE /opt/bitnami/${TARGET_DIR}/licenses/nginx-exporter-${BUILD_VERSION}.txt
    cp -f ${PACKAGE} /opt/bitnami/${TARGET_DIR}/bin/${PACKAGE}
    popd

    rm -rf ${PACKAGE}
EOT

FROM docker.io/bitnami/minideb:trixie as stage-0

ARG BUILD_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
ENV HOME="/" \
    OS_ARCH="${TARGETARCH}" \
    OS_FLAVOUR="debian-13" \
    OS_NAME="linux" \
    APP_VERSION="${BUILD_VERSION}" \
    BITNAMI_APP_NAME="nginx-exporter" \
    PATH="/opt/bitnami/nginx-exporter/bin:$PATH"

LABEL org.opencontainers.image.ref.name="${BUILD_VERSION}-trixie" \
      org.opencontainers.image.title="nginx-exporter" \
      org.opencontainers.image.version="${BUILD_VERSION}"

# Install required system packages and dependencies
COPY --link --from=golang-builder /opt/bitnami/ /opt/bitnami/
RUN <<EOT bash
    set -e
    install_packages ca-certificates curl gzip procps tar
    ln -s /opt/bitnami/nginx-exporter/bin/nginx-prometheus-exporter /usr/bin/exporter
EOT

EXPOSE 9113

WORKDIR /opt/bitnami/nginx-exporter
USER 1001
ENTRYPOINT [ "nginx-prometheus-exporter" ]

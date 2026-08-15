# Stage 1: Build the Go binary and frontend
FROM golang:1.25-alpine AS builder

ARG APP_NAME
ARG VERSION
ARG BUILDDATE
ARG COMMIT
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

RUN echo "Building for $TARGETPLATFORM"

# Install build dependencies including gcc for CGO
RUN apk add --no-cache nodejs npm gcc musl-dev

WORKDIR /build

# Copy source
COPY go.mod go.sum ./
COPY main.go .
COPY cmd ./cmd
COPY internal ./internal
COPY web ./web
COPY locales ./locales

# Build frontend
WORKDIR /build/web/static
RUN npm ci
RUN npm run build

# Build Go binary
WORKDIR /build
RUN CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o /tmp/${APP_NAME} .

# Stage 2: Runtime image
FROM ubuntu:22.04
ARG APP_NAME
ARG VERSION
ARG BUILDDATE
ARG COMMIT
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
RUN echo "I'm building for $TARGETPLATFORM"

# Install dependencies
RUN apt-get update && apt-get -y install \
    wget unzip libavahi-compat-libdnssd-dev curl

RUN case ${TARGETARCH} in \
         "amd64")  PKG_ARCH=x86_64  ;; \
         "arm64")  PKG_ARCH=aarch64  ;; \
    esac \
    && cd /tmp \
    && wget https://github.com/bitxeno/usbmuxd2/releases/download/v0.0.4/usbmuxd2-ubuntu-${PKG_ARCH}.tar.gz \
    && tar zxf usbmuxd2-ubuntu-${PKG_ARCH}.tar.gz \
    && dpkg -i ./libusb_1.0.26-1_${PKG_ARCH}.deb \
    && dpkg -i ./libgeneral_1.0.0-1_${PKG_ARCH}.deb \
    && dpkg -i ./libplist_2.6.0-1_${PKG_ARCH}.deb \
    && dpkg -i ./libtatsu_1.0.3-1_${PKG_ARCH}.deb \
    && dpkg -i ./libimobiledevice-glue_1.3.0-1_${PKG_ARCH}.deb \
    && dpkg -i ./libusbmuxd_2.3.0-1_${PKG_ARCH}.deb \
    && dpkg -i ./libimobiledevice_1.3.1-1_${PKG_ARCH}.deb \
    && dpkg -i ./usbmuxd2_1.0.0-1_${PKG_ARCH}.deb

# Install PlumeImpactor
RUN case ${TARGETARCH} in \
         "amd64")  PKG_ARCH=x86_64  ;; \
         "arm64")  PKG_ARCH=aarch64  ;; \
    esac \
    && cd /tmp \
    && wget https://github.com/bitxeno/PlumeImpactor/releases/download/v2.2.3-patch.4/plumesign-linux-${PKG_ARCH}.tar.gz \
    && tar zxf plumesign-linux-${PKG_ARCH}.tar.gz \
    && mv plumesign-linux-${PKG_ARCH} /usr/bin/plumesign \
    && chmod +x /usr/bin/plumesign

# Download anisette dependency library
RUN case ${TARGETARCH} in \
         "amd64")  PKG_ARCH=x86_64  ;; \
         "arm64")  PKG_ARCH=arm64-v8a  ;; \
    esac \
    && mkdir -p /keep \
    && cd /keep \
    && wget https://apps.mzstatic.com/content/android-apple-music-apk/applemusic.apk \
    && unzip applemusic.apk lib/${PKG_ARCH}/libstoreservicescore.so lib/${PKG_ARCH}/libCoreADI.so \
    && rm applemusic.apk

# Download DeveloperDiskImages snapshot
RUN mkdir -p /keep \
    && cd /tmp \
    && wget -O DeveloperDiskImages.zip https://github.com/bitxeno/DeveloperDiskImages/archive/refs/heads/main.zip \
    && unzip DeveloperDiskImages.zip \
    && mv DeveloperDiskImages-main /keep/DeveloperDiskImages \
    && rm -rf /keep/DeveloperDiskImages/iOS_DDI \
    && rm -rf /keep/DeveloperDiskImages/.gitignore

# Install tzdata to support timezone updates.
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install tzdata

# Clear apt cache and temporary data to reduce image size.
RUN apt-get clean
RUN cd /tmp && rm -rf ./*.deb && rm -rf ./*.tar.gz && rm -rf ./*.zip && rm -rf ./*.apk

# Copy built binary and config from builder
RUN mkdir -p /keep
COPY ./doc/config.yaml.example /keep/config.yaml
COPY --from=builder /tmp/${APP_NAME} /usr/bin/${APP_NAME}
RUN chmod +x /usr/bin/${APP_NAME}

# The lockdown records have been moved to /data.
RUN rm -rf /var/lib/lockdown && mkdir -p /data/lockdown && ln -s /data/lockdown /var/lib/lockdown

# Generate startup script
COPY ./doc/scripts/usbmuxd /etc/init.d/usbmuxd
RUN chmod +x /etc/init.d/usbmuxd
RUN printf '#!/bin/sh\n\nmkdir -p /data/lockdown\nmkdir -p /data/PlumeImpactor\nmkdir -p /data/PlumeImpactor/pairing_files\nmkdir -p $HOME/.config\n[ ! -e "$HOME/.config/PlumeImpactor" ] && ln -s /data/PlumeImpactor $HOME/.config/PlumeImpactor\n\nif [ -d "/keep/lib" ]; then  \n    rm -rf /data/PlumeImpactor/lib\n    cp -rf /keep/lib /data/PlumeImpactor/lib\n    rm -rf /keep/lib\nfi  \n\nif [ -d "/keep/DeveloperDiskImages" ]; then  \n    rm -rf /data/DeveloperDiskImages\n    cp -rf /keep/DeveloperDiskImages /data/DeveloperDiskImages\nfi  \n\nif [ ! -f "/data/config.yaml" ]; then  \n    cp /keep/config.yaml /data/config.yaml\nfi  \n\n/etc/init.d/usbmuxd start\n\n/usr/bin/%s server -p ${SERVICE_PORT:-80} -c /data/config.yaml\n\n' ${APP_NAME} >> /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80
VOLUME /data

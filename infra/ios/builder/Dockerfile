# Builder delle app iOS (IOSB-001): Swift per Linux e xtool, che compila un
# pacchetto SwiftPM in un'app iOS con l'SDK estratto da Xcode.xip. L'SDK
# non sta nell'immagine: si installa in /work (IOS_DIR) con il comando sdk.
FROM swift:6.4.1-noble

ARG XTOOL_VERSION=1.22.2

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip zip \
  && rm -rf /var/lib/apt/lists/*

# L'AppImage si estrae subito: nel container non c'è FUSE per montarla.
RUN curl -fsSL -o /tmp/xtool.AppImage \
    "https://github.com/xtool-org/xtool/releases/download/${XTOOL_VERSION}/xtool-x86_64.AppImage" \
  && chmod +x /tmp/xtool.AppImage \
  && cd /opt && /tmp/xtool.AppImage --appimage-extract >/dev/null \
  && mv /opt/squashfs-root /opt/xtool \
  && chmod -R a+rX /opt/xtool \
  && rm /tmp/xtool.AppImage
# Dal PATH, non da un link: xtool cerca le sue librerie accanto a sé.
ENV PATH=/opt/xtool/usr/bin:$PATH

COPY ios-build.sh /usr/local/bin/ios-build
# HOME dentro /work: lì xtool e SwiftPM tengono SDK e cache, sull'host.
ENV HOME=/work/home
WORKDIR /work
ENTRYPOINT ["ios-build"]

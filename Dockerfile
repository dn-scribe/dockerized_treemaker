# ─── Stage 1: Build TreeMaker ───────────────────────────────────────────────
#
# Ubuntu 24.04 ships wx3.2, which has proper GTK3.24 support.
# wx3.0.5 (Ubuntu 22.04) crashes at startup due to a private style-provider
# interface mismatch with GTK3.24 — fixed in wx3.2.
#
FROM ubuntu:24.04 AS app-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git g++ gcc make \
    libwxgtk3.2-dev \
    libgtk-3-dev \
    pkg-config \
    zip wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/bugfolder/TreeMaker.git /src

WORKDIR /src/linux

# Apply all wx2.6→wx3 compatibility patches via the patches script.
COPY patches.sh /patches.sh
RUN bash /patches.sh

# WXPATH=/usr/bin → WXCONFIG=/usr/bin/wx-config (system wx3 binary)
RUN mkdir -p build/release \
 && make WXPATH=/usr/bin BUILD=release

# tmpath: prints the data-directory name ("TreeMaker 5").
RUN gcc -I../Source \
    -DINSTALL_PREFIX=\"/usr/local/\" \
    -o build/release/tmpath tmpath.c

# Stage resources; data dir is "TreeMaker 5" per TM_APP_NAME_STR in tmVersion.h.
RUN DATADIR="TreeMaker 5" \
 && mkdir -p "/opt/tm-res/${DATADIR}" \
 && cp ../Source/images/SplashScreen.png \
       ../Source/about/about.htm \
       resources/Icon_doc_48.png \
       resources/Icon_app_48.png \
       resources/Icon_app.ppm \
    "/opt/tm-res/${DATADIR}/" \
 && zip -qj "/opt/tm-res/${DATADIR}/help.zip" ../Source/help/*

# noVNC v1.4.0
RUN wget -qO /tmp/novnc.tar.gz \
    https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz \
 && tar -xzf /tmp/novnc.tar.gz -C /opt \
 && mv /opt/noVNC-1.4.0 /opt/novnc \
 && ln -sf /opt/novnc/vnc.html /opt/novnc/index.html \
 && rm /tmp/novnc.tar.gz


# ─── Stage 2: Runtime ────────────────────────────────────────────────────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libwxgtk3.2-1t64 \
    xvfb \
    x11vnc \
    fonts-dejavu-core \
    python3 python3-pip \
 && pip3 install --no-cache-dir --break-system-packages websockify \
 && apt-get purge -y python3-pip \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

COPY --from=app-builder /src/linux/build/release/TreeMaker /usr/local/bin/TreeMaker
COPY --from=app-builder /src/linux/build/release/tmpath    /usr/local/bin/tmpath
COPY --from=app-builder /opt/tm-res/                        /usr/local/share/
COPY --from=app-builder /opt/novnc/                         /opt/novnc/

RUN mkdir -p /root/.config/gtk-3.0 && \
    printf '[Settings]\ngtk-theme-name=Adwaita\ngtk-application-prefer-dark-theme=0\n' \
    > /root/.config/gtk-3.0/settings.ini

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6080

ENTRYPOINT ["/start.sh"]

FROM ubuntu:20.04 AS motion_build

WORKDIR /tmp

# Setup build environment
RUN export DEBIAN_FRONTEND=noninteractive; \
    export DEBCONF_NONINTERACTIVE_SEEN=true; \
    apt-get update -qqy && apt-get install -qqy --option Dpkg::Options::="--force-confnew" --no-install-recommends \
    autoconf automake build-essential pkgconf libtool libzip-dev libjpeg-dev tzdata \
    git libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libavdevice-dev \
    libwebp-dev gettext autopoint libmicrohttpd-dev ca-certificates imagemagick curl wget \
    libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libavdevice-dev ffmpeg x264 && \
    apt-get --quiet autoremove --yes && \
    apt-get --quiet --yes clean && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/Motion-Project/motion.git  && \
   cd motion  && \
   autoreconf -fiv && \
   ./configure && \
   make clean && \
   make && \
   make install && \
   cd .. && \
   rm -fr motion

#################################################

FROM ubuntu:20.04 as motioneye_build
WORKDIR /tmp

RUN export DEBIAN_FRONTEND=noninteractive; \
    export DEBCONF_NONINTERACTIVE_SEEN=true; \
    apt-get update -qqy && apt-get install -qqy --option Dpkg::Options::="--force-confnew" --no-install-recommends \
    git ssh curl motion ffmpeg v4l-utils ca-certificates \
    build-essential python2.7 \
    libffi-dev libzbar-dev libzbar0 \
    python2.7-dev libssl-dev libcurl4-openssl-dev libjpeg-dev \
    python-pil lsb-release && \
    apt-get --quiet autoremove --yes && \
    apt-get --quiet --yes clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py && \
    python2.7 get-pip.py

RUN git clone https://github.com/ccrisan/motioneye.git && \
    pip install /tmp/motioneye

####################################################

FROM ubuntu:20.04

ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.docker.dockerfile="Dockerfile" \
    org.label-schema.license="GPLv3" \
    org.label-schema.name="motioneye" \
    org.label-schema.url="https://github.com/ccrisan/motioneye/wiki" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/alejandrorivera/motioneye.git"

RUN export DEBIAN_FRONTEND=noninteractive; \
    export DEBCONF_NONINTERACTIVE_SEEN=true; \
    apt-get update -qqy && apt-get install -qqy --option Dpkg::Options::="--force-confnew" --no-install-recommends \
    curl ffmpeg v4l-utils tini \
    python2.7 python-pil lsb-release  && \
    apt-get --quiet autoremove --yes && \
    apt-get --quiet --yes clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=motion_build /usr /usr
COPY --from=motioneye_build /usr/local /usr/local
COPY --from=motioneye_build /tmp/motioneye/extra/motioneye.conf.sample /usr/share/motioneye/extra/

# R/W needed for motioneye to update configurations
VOLUME /etc/motioneye
VOLUME /var/log/motioneye
VOLUME /var/lib/motioneye

CMD test -e /etc/motioneye/motioneye.conf || \
    cp /usr/share/motioneye/extra/motioneye.conf.sample /etc/motioneye/motioneye.conf ; \
    # We need to chown at startup time since volumes are mounted as root. This is fugly.
    # chown -R motion:motion /var/run /var/log /etc/motioneye /var/lib/motioneye /usr/share/motioneye/extra ; \
    # su motion motion -s /bin/bash -c "/usr/local/bin/meyectl startserver -c /etc/motioneye/motioneye.conf"
    exec /usr/bin/tini /usr/local/bin/meyectl -- startserver -l -c /etc/motioneye/motioneye.conf 

EXPOSE 8765

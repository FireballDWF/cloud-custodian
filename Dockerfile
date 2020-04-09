FROM debian:testing-slim as build-env

LABEL name="custodian" \
      description="Cloud Management Rules Engine" \
      repository="http://github.com/cloud-custodian/cloud-custodian" \
      homepage="http://github.com/cloud-custodian/cloud-custodian" \
      maintainer="Custodian Community <https://cloudcustodian.io>"

####
# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
	&& rm -rf /var/lib/apt/lists/*

ENV PYTHON_VERSION 3.8.2 
ENV CFLAGS="-fno-semantic-interposition" 
ENV LDFLAGS="-fno-semantic-interposition" 

RUN set -ex \
	\
	&& savedAptMark="$(apt-mark showmanual)" \
	&& apt-get update && apt-get install -y --no-install-recommends \
		dpkg-dev \
		gcc \
		libbluetooth-dev \
		libbz2-dev \
		libc6-dev \
		libexpat1-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		tk-dev \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
		curl 
RUN wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" 
RUN wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" 
RUN mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz 
RUN cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && ./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--with-lto \
		--enable-shared \
		--enable-option-checking=fatal \
		--with-system-expat \
		--with-system-ffi \
		--with-ensurepip \
   && make -j "$(nproc)" \
   && make install \
	&& ldconfig \
	\
	&& apt-mark auto '.*' > /dev/null \
	&& apt-mark manual $savedAptMark \
	&& find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	&& python3 --version


####
RUN adduser --disabled-login custodian \
 && mkdir /output \
 && chown custodian: /output

# Transfer Custodian source into container by directory
# to minimize size
ADD pyproject.toml poetry.lock README.md /src/
ADD c7n /src/c7n/
ADD tools/c7n_gcp /src/tools/c7n_gcp
ADD tools/c7n_azure /src/tools/c7n_azure
ADD tools/c7n_kube /src/tools/c7n_kube
ADD tools/c7n_org /src/tools/c7n_org
ADD tools/c7n_mailer /src/tools/c7n_mailer

WORKDIR /src

RUN python3 -m venv /usr/local 
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3 \
 && . /usr/local/bin/activate 
RUN $HOME/.poetry/bin/poetry install --no-dev \
RUN cd tools/c7n_azure && $HOME/.poetry/bin/poetry install && cd ../.. \
RUN cd tools/c7n_gcp && $HOME/.poetry/bin/poetry install && cd ../.. \
RUN cd tools/c7n_kube && $HOME/.poetry/bin/poetry install && cd ../..

# Distroless Container as base
FROM gcr.io/distroless/base
LABEL name="custodian" \
      description="Cloud Management Rules Engine" \
      repository="http://github.com/cloud-custodian/cloud-custodian" \
      homepage="http://github.com/cloud-custodian/cloud-custodian" \
      maintainer="Custodian Community <https://cloudcustodian.io>"
COPY --from=build-env /src /src
COPY --from=build-env /usr/local /usr/local
COPY --from=build-env /output /output
COPY --from=build-env /etc/passwd /etc/passwd
USER custodian
WORKDIR /home/custodian
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"
VOLUME ["/home/custodian"]
ENTRYPOINT ["/usr/local/bin/custodian"]
CMD ["--help"]
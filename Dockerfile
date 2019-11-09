FROM python:slim

LABEL name="custodian" \
      description="Cloud Management Rules Engine" \
      repository="http://github.com/cloud-custodian/cloud-custodian" \
      homepage="http://github.com/cloud-custodian/cloud-custodian" \
      maintainer="Custodian Community <https://cloudcustodian.io>"

# Transfer Custodian source into container by directory
# to minimize size
ADD setup.py README.md requirements.txt /src/
ADD c7n /src/c7n/

WORKDIR /src

RUN adduser --disabled-login custodian
RUN apt-get --yes update \
 && apt-get --yes install build-essential --no-install-recommends \
 && pip3 install -r requirements.txt  . \
 && apt-get --yes remove build-essential \
 && apt-get purge --yes --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
 && rm -Rf /var/cache/apt/ \
 && rm -Rf /var/lib/apt/lists/* \
 && rm -Rf /src/ \
 && rm -Rf /root/.cache/ \
 && mkdir /output \
 && chown custodian: /output

USER custodian
WORKDIR /home/custodian
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"
VOLUME ["/home/custodian"]
ENTRYPOINT ["/usr/local/bin/custodian"]
CMD ["--help"]

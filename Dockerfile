FROM ubuntu:18.04
ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
RUN apt-get update

RUN apt-get install -y wget && rm -rf /var/lib/apt/lists/*


RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 
RUN conda --version

RUN conda config --add channels defaults
RUN conda config --add channels bioconda
RUN conda config --add channels conda-forge

RUN conda install -c conda-forge -y awscli=1.22.77
RUN conda install -c bioconda trinity=2.13.2
RUN conda install -c bioconda cutadapt=3.7
RUN conda install -c bioconda bbmap=38.22
RUN conda install -c bioconda fastq-pair=1.0
RUN conda install -c bioconda spades=3.13.0

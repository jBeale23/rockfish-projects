FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and ensure package versions are up to date, Install necessary packages
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
	unzip \
	wget && \
    rm -rf /var/lib/apt/lists/*

# Download and install APBS
RUN wget --no-check-certificate https://github.com/Electrostatics/apbs/releases/download/v3.4.1/APBS-3.4.1.Linux.zip && \
unzip APBS-3.4.1.Linux.zip -d /opt/apbs && \
rm APBS-3.4.1.Linux.zip && \
mv /opt/apbs/APBS-3.4.1.Linux/* /opt/apbs && \
rmdir /opt/apbs/APBS-3.4.1.Linux

FROM ubuntu:24.04 AS runtime

COPY --from=build /opt/apbs /opt/apbs
ENV PATH="/opt/apbs/bin:${PATH}"

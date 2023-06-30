ARG D_COMPILER=ldc-1.30.0
ARG BINARY_NAME=soop2
ARG WEB_PORT=8000

FROM debian:bookworm-slim AS build

ARG D_COMPILER

# install dependencies
RUN echo "Running on $(uname -a)" && apt-get update && apt-get install -y \
  bash \
  curl wget xz-utils \
  gcc make libc6-dev libcurl4 \
  git libxml2 \
  libssl-dev zlib1g-dev openssl \
  && rm -rf /var/lib/apt/lists/* && apt autoremove -y && apt clean


# install dlang
RUN curl -fsS https://dlang.org/install.sh | bash -s install ${D_COMPILER} \
  && echo "source ~/dlang/${D_COMPILER}/activate" >> ~/.bashrc

# copy source to /prj
COPY . /prj

# run build
RUN bash -l -c "cd /prj && dub build && rm -rf .dub"

FROM debian:bookworm-slim AS runtime

ARG BINARY_NAME
ARG WEB_PORT

# install dependencies
RUN apt-get update && apt-get install -y \
  bash \
  libssl-dev zlib1g-dev openssl \
  && rm -rf /var/lib/apt/lists/* && apt autoremove -y && apt clean

# copy built project
COPY --from=build /prj /app

# environment
EXPOSE ${WEB_PORT}

# run
RUN ln -s /app/${BINARY_NAME} /app/run

WORKDIR /app
ENTRYPOINT ["/app/run"]
# CMD []

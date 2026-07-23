# Root Dockerfile for the Flicker-hosted demo app.
#
# Flicker clones the repository root for manifest-based builds, so this file
# builds the Phoenix demo from the /demo subdirectory while keeping the rest of
# the repository layout intact.
#
# The demo uses the package from this checkout, so the image includes the
# LiveCode source before resolving the demo's path dependency.

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=28.0.2
ARG DEBIAN_VERSION=trixie-20260610-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs ./
COPY lib lib
COPY priv priv

WORKDIR /app/demo
COPY demo/mix.exs demo/mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY demo/config/config.exs demo/config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY demo/priv priv
COPY demo/lib lib
RUN mix compile

COPY demo/assets assets
RUN mix assets.deploy

COPY demo/config/runtime.exs config/
COPY demo/rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/demo/_build/${MIX_ENV}/rel/demo ./

USER nobody

CMD ["/app/bin/server"]

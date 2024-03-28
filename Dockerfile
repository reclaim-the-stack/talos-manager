# This Dockerfile produces a production ready image for running in Kubernetes.

ARG RUBY_VERSION=3.2.0
FROM ruby:${RUBY_VERSION}-alpine as base

WORKDIR /app

ENV BUNDLE_PATH=vendor/bundle
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLE_CLEAN=true

FROM base as talosctl

ARG TALOS_VERSION=1.6.7
RUN wget https://github.com/siderolabs/talos/releases/download/v${TALOS_VERSION}/talosctl-linux-amd64 -O /usr/local/bin/talosctl
RUN chmod +x /usr/local/bin/talosctl

FROM base as gems

# git for git based Gemfile definitions
# build-base for native extensions
# postgresql-dev for pg gem
RUN apk add git build-base postgresql-dev

COPY .ruby-version .
COPY Gemfile* ./

RUN bundle install

RUN rm -rf vendor/bundle/ruby/*/cache

FROM base

# libc6-compat required by nokogiri aarch64-linux
# libpq required by pg
# tzdata required by tzinfo
# libcurl required by typhoeus
# wget for talosctl installation
# curl is required for the heroku release command output
RUN apk add wget libc6-compat tzdata libcurl libpq curl

COPY --from=gems /app /app
COPY --from=talosctl /usr/local/bin/talosctl /usr/local/bin/talosctl
COPY . .

ENV RAILS_ENV=production

# Required to boot but not used for asset precompilation
ENV SECRET_KEY_BASE=foo

RUN bundle exec rails assets:precompile

CMD ["bin/rails", "server"]

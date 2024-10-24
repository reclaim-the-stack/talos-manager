# This Dockerfile produces a production ready image of talos-manager.

ARG RUBY_VERSION=3.3.5
FROM ruby:${RUBY_VERSION}-slim as base

WORKDIR /app

ENV BUNDLE_PATH=vendor/bundle
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLE_CLEAN=true

FROM base as talosctl

RUN apt-get update -qq && apt-get install --no-install-recommends -y wget

ARG TALOS_VERSION=1.8.1
# TODO: This should use TARGETPLATFORM to determine the correct binary to download
RUN wget https://github.com/siderolabs/talos/releases/download/v${TALOS_VERSION}/talosctl-linux-amd64 -O /usr/local/bin/talosctl
RUN chmod +x /usr/local/bin/talosctl

FROM base as gems

# git for git based Gemfile definitions
# build-essential + pkg-config for native extensions
# libpq-dev for pg gem
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential pkg-config git libpq-dev

COPY .ruby-version .
COPY Gemfile* ./

RUN bundle install

RUN rm -rf vendor/bundle/ruby/*/cache

FROM base

# wget for talosctl installation
# curl is required for typhoeus and the heroku release command output
# libsqlite3-0 for sqlite3
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y wget curl libsqlite3-0 postgresql-client file && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=gems /app /app
COPY --from=talosctl /usr/local/bin/talosctl /usr/local/bin/talosctl
COPY . .

ENV RAILS_ENV=production

# Required to boot but not used for asset precompilation
ENV SECRET_KEY_BASE=foo

RUN bundle exec rails assets:precompile

CMD ["bin/rails", "server"]

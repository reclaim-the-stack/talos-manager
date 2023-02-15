# This Dockerfile produces a production ready image for running mynewsdesk in Kubernetes.

ARG RUBY_VERSION=3.2.0
FROM ruby:${RUBY_VERSION}-alpine as base

WORKDIR /app

ENV BUNDLE_PATH=vendor/bundle
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLE_CLEAN=true

FROM base as gems

# git for git based Gemfile definitions
# build-base for native extensions
RUN apk add git build-base

COPY .ruby-version .
COPY Gemfile* .

RUN bundle install

RUN rm -rf vendor/bundle/ruby/*/cache

FROM base

# libc6-compat required by nokogiri aarch64-linux
# tzdata required by tzinfo
RUN apk add libc6-compat tzdata

COPY --from=gems /app /app
COPY . .

ENV RAILS_ENV=production

# Required to boot but not used for asset precompilation
ENV SECRET_KEY_BASE=foo

RUN bundle exec rails assets:precompile

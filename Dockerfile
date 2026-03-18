FROM ruby:3.4 AS ruby

# Check https://rubygems.org/gems/bundler/versions for the latest version.
ARG UNAME=app
ARG UID=1000
ARG GID=1000

## Install Vim (optional)
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  vim-tiny

RUN gem install bundler

RUN groupadd -g ${GID} -o ${UNAME}
RUN useradd -m -d /app -u ${UID} -g ${GID} -o -s /bin/bash ${UNAME}
RUN mkdir -p /gems && chown ${UID}:${GID} /gems

ENV PATH="$PATH:/app/exe:/app/bin"
USER $UNAME

ENV BUNDLE_PATH /gems

WORKDIR /app
COPY --chown=${UID}:${GID} Gemfile Gemfile.lock opensearch-sugar.gemspec ./
COPY --chown=${UID}:${GID} lib/opensearch/sugar/version.rb ./lib/opensearch/sugar/version.rb


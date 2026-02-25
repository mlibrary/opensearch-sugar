# Multi-stage build optimized for integration testing
FROM ruby:3.4-slim AS base

# Install only essential dependencies
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  build-essential \
  git \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG UNAME=app
ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} ${UNAME} && \
    useradd -m -d /app -u ${UID} -g ${GID} -s /bin/bash ${UNAME}

# Set up gem installation directory
ENV BUNDLE_PATH=/gems \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

RUN mkdir -p /gems && chown ${UID}:${GID} /gems

WORKDIR /app

# Stage for dependencies
FROM base AS dependencies

# Copy only dependency files first for better caching
COPY --chown=${UID}:${GID} Gemfile Gemfile.lock *.gemspec ./
COPY --chown=${UID}:${GID} lib/opensearch/sugar/version.rb ./lib/opensearch/sugar/

USER ${UNAME}

# Update RubyGems and install bundler
RUN gem update --system --silent && \
    gem install bundler --no-document

# Install dependencies
RUN bundle install

# Final stage for testing
FROM base AS test

# Copy installed gems from dependencies stage
COPY --from=dependencies --chown=${UID}:${GID} /gems /gems

USER ${UNAME}
WORKDIR /app

# Copy application code
COPY --chown=${UID}:${GID} . .

# Set PATH to include local bins
ENV PATH="/app/bin:/app/exe:${PATH}"

# Health check
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=3 \
  CMD ruby -e "puts 'healthy'" || exit 1

# Default command for running tests
CMD ["bundle", "exec", "rspec"]



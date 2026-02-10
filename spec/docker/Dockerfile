FROM ruby:ubuntu as ruby

ARG UNAME=app
ARG GNAME=$UNAME
ARG UID=1000
ARG GID=1000

#ENV BUNDLE_PATH /gems

RUN apk update
RUN apk update && apk upgrade
RUN apk add build-base at ripgrep ruby-bigdecimal sqlite-dev mariadb-dev mariadb-client git
#  RUN apk add bash

RUN addgroup --gid "$GID" "$GNAME" \
&&  adduser \
    --system  \
    --disabled-password \
    --gecos "" \
    --home "/app" \
    --ingroup "$GNAME" \
    --no-create-home \
    --uid "$UID" \
    "$UNAME"

RUN mkdir -p /gems && chown ${UID}:${GID} /gems

RUN echo 'alias l=/usr/bin/bat' >> /etc/ash.ashrc
RUN echo 'alias less=/usr/bin/bat' >> /etc/ash.ashrc

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN bundle config --global frozen 1

ENV PATH="$PATH:/app/exe:/app/bin"
WORKDIR /app

COPY --chown=${UID}:${GID} . /app

COPY Gemfile .
RUN if [ -e "Gemfile.lock" ]; then cp "Gemfile.lock" ./; fi

RUN gem update --system
RUN gem install ruby-json


RUN bundle install

CMD ["bundle exec pry"]


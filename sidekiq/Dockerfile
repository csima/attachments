FROM ubuntu:16.04

# Install packages for building ruby
RUN apt-get update && apt-get install -y --force-yes build-essential \
	wget git zlib1g-dev libssl-dev libreadline-dev libyaml-dev libxml2-dev libxslt-dev \
	ruby ruby-dev pigz pv && apt-get clean
RUN gem install bundler

COPY . /attachments/
WORKDIR /attachments/
RUN bundle install

#ENV HONEYBADGER_API_KEY=10ad91e2
#ENV HONEYBADGER_LOGGING_PATH=/minilab/logs/honeybadger.log
#ENV HONEYBADGER_ENV=production
#ENV REDIS_URL=redis://redis:6379/0

CMD ["sh", "init_sidekiq.sh"]

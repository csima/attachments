FROM golang

# Install packages for building ruby


COPY . /attachments/
WORKDIR /attachments/
RUN bundle install

#ENV HONEYBADGER_API_KEY=10ad91e2
#ENV HONEYBADGER_LOGGING_PATH=/minilab/logs/honeybadger.log
#ENV HONEYBADGER_ENV=production
#ENV REDIS_URL=redis://redis:6379/0

CMD ["sh", "init_sidekiq.sh"]

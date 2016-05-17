FROM golang

# Install packages for building ruby
COPY . /attachments/
WORKDIR /attachments/
RUN bundle install

CMD ["sh", "init_sidekiq.sh"]

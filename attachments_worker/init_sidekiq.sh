#!/bin/sh
bundle exec sidekiq -r ./server.rb -L sidekiq.log

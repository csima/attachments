require 'sidekiq'
require 'sidekiq-status'
require 'logger'
require 'pry'
require 'google/api_client'
require 'aws-sdk'

S3_URL = "https://attachments.storage.s3-website-us-west-1.amazonaws.com"
S3_BUCKET = "attachments.storage"
AWS_ACCESSKEY = "AKIAJAFC5GYPZA6E3RYQ"
AWS_SECRETKEY = "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"
AWS_REGION = "us-west-1"
ROOT_FOLDER = File.expand_path("../../", __FILE__)

require_relative 'workers/worker'
require_relative 'workers/main_worker'
require_relative 'workers/message_worker'
require_relative 'workers/attachment_worker'
require_relative 'workers/compress_worker'
require_relative 'workers/zip_worker'

redis_url = ENV['DB_PORT'].sub("tcp","redis")
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Status::ServerMiddleware, expiration: 300 # default
    config.redis = { url: redis_url }
  end
  config.client_middleware do |chain|
    chain.add Sidekiq::Status::ClientMiddleware
    config.redis = { url: redis_url }
  end
end

Sidekiq.default_worker_options = { 'backtrace' => true, 'retry' => 3 }
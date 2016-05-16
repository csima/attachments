require 'sidekiq'
require 'sidekiq-status'
require 'logger'
require 'pry'
require 'google/api_client'
require 'aws-sdk'
require 'remote_syslog_logger'
require 'rollbar'
require 'newrelic_rpm'

S3_URL = ENV['S3_URL']
S3_BUCKET = ENV['S3_BUCKET']
AWS_ACCESSKEY = ENV['AWS_ACCESSKEY']
AWS_SECRETKEY = ENV['AWS_SECRETKEY']
AWS_REGION = ENV['AWS_REGION']
redis_url = ENV['REDIS']

Rollbar.configure do |config|
  config.access_token = 'd74c783ffb0e46cdbbbb09d76547404e'
end

#Rollbar.error('Sidekiq Start')

if ENV['WORKER_TYPE'] == "zip"
	require_relative 'workers/compress_worker'
	require_relative 'workers/zip_worker'
	
	Sidekiq.configure_server do |config|
		Sidekiq::Logging.logger = RemoteSyslogLogger.new('logs3.papertrailapp.com', 28391, program: "sidekiq-worker")

	  config.server_middleware do |chain|
	    chain.add Sidekiq::Status::ServerMiddleware, expiration: 300 # default
		config.redis = { :namespace => 'zip', :url => redis_url + '/1' }
	  end
	  config.client_middleware do |chain|
	    chain.add Sidekiq::Status::ClientMiddleware
		config.redis = { :namespace => 'zip', :url => redis_url + '/1' }
	  end
	end
	puts "Loaded as zip worker"
else
	require_relative 'workers/worker'
	require_relative 'workers/main_worker'
	require_relative 'workers/message_worker'
	require_relative 'workers/attachment_worker'
	
	Sidekiq.configure_server do |config|
	  Sidekiq::Logging.logger = RemoteSyslogLogger.new('logs3.papertrailapp.com', 28391, program: "sidekiq-worker")

	  config.server_middleware do |chain|
	    chain.add Sidekiq::Status::ServerMiddleware, expiration: 300 # default
	    config.redis = { url: redis_url }
	  end
	  config.client_middleware do |chain|
	    chain.add Sidekiq::Status::ClientMiddleware
	    config.redis = { url: redis_url }
	  end
	end
	puts "Loaded as main worker"
end

Sidekiq.default_worker_options = { 'backtrace' => true, 'retry' => 3 }

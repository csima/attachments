redis_url = ENV['REDIS']

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
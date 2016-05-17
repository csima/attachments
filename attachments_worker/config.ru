require 'sidekiq'
redis_url = 'redis://127.0.0.1'
Sidekiq.configure_client do |config|
    config.redis = { url: redis_url }
end

require 'sidekiq/web'
run Sidekiq::Web

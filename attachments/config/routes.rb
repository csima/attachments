require 'sidekiq/web'
require 'sidekiq-status/web'


Rails.application.routes.draw do
	get 'home/index'
	root to: 'home#login'
	resources :sessions, only: :index
	get "/auth/:provider/callback" => 'sessions#create'
	get "/signout" => "sessions#destroy", :as => :signout
	get '/status/:account_id/:identity_id' => 'home#status'
	get '/message/:accountid/count' => 'home#message_count'
	get '/backup' => 'home#backup'
	get '/cancel' => 'home#cancel_job'
	get '/home' => 'home#home'
	get '/save_attachments' => 'home#save_attachments'
	get '/save_status/:jobid' => 'home#save_status'
	get '/compress' => 'home#compress'
	get '/compress_status/:jobid' => 'home#compress_status'
end

#   class SidekiqWeb < ::Sidekiq::Web
#     disable :sessions
#   end

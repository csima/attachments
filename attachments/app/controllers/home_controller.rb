
class HomeController < ApplicationController
  
  def index
  end
  
  def login
	  if signed_in?
		  redirect_to "/home"
		  return
	  end
	  render layout: false
  end
  
  def home	  
	  if signed_in? == false
		  redirect_to "/"
		  return
	  end
	  
	  gon.test = "init"
	  gon.account_id = current_user.id
	  gon.identity_id = current_user.identities.first.uid
	  
	  render layout: false
  end
  
  def status
	  account_id = params[:account_id]
	  identity_id = params[:identity_id]
	  prefix = "#{account_id}:#{identity_id}"
	  
	  message_count = $redis.llen("#{prefix}:messageids_list")
	  message_completed_count = $redis.hlen("#{account_id}:#{identity_id}:messageids")
	  attachment_count = $redis.llen("#{prefix}:attachmentids_list")
	  attachment_completed_count = $redis.hlen("#{account_id}:#{identity_id}:attachmentids")
	  status_hash = {'message_count' => message_count, 'message_completed_count' => message_completed_count, 'attachment_count' => attachment_count, 'attachment_completed_count' => attachment_completed_count}
	  render :json => status_hash
  end
  
  def cancel_job
	  identity_id = current_user.identities.first.uid
	  account_id = current_user.id
	  
	  $redis.set("#{account_id}:#{identity_id}:cancel", "true")
	  render :json => {'status' => 'OK'}
  end
  
  def compress
	  jobid = Sidekiq::Client.push('class' => 'CompressWorker', 'args' => [{'account_id' => current_user.id, 'identity_id' => current_user.identities.first.uid}])
	  render :json => {'jobid' => jobid}
  end

  def save_attachments
	  jobid = Sidekiq::Client.push('class' => 'S3DownloadControllerWorker', 'args' => [{'account_id' => current_user.id, 'identity_id' => current_user.identities.first.uid}])
	  render :json => {'jobid' => jobid}
  end
  
  def compress_status
	  jobid = params[:jobid]
	  account_id = current_user.id
	  identity_id = current_user.identities.first.uid
	  
	  status = Sidekiq::Status::get_all jobid
	  
	  render :json => status
  end
  
  def save_status
	  account_id = current_user.id
	  identity_id = current_user.identities.first.uid
	  
	  list_total = $redis.get("#{account_id}:#{identity_id}:zip:list_total")
	  current_count = $redis.llen("#{account_id}:#{identity_id}:zip:list")
	  
	  render :json => {'total' => list_total, 'count' => current_count}
  end
  
	def backup
		redis_url = ENV['DB_PORT'].sub("tcp","redis")
		Sidekiq.configure_client do |config|
		    config.redis = { url: redis_url }
		end

		puts params
		#@account_id = params[:account_id]
		#@identity_id = params[:identity_id]
		@identity = current_user.identities.first
	
		query = params[:query]
		@jobid = Sidekiq::Client.push('class' => 'MainWorker', 'queue' => 'high', 'args' => [{'token' => @identity.fresh_token, 'command' => 'search_emails', 'query' => "has:attachment #{query}", 'account_id' => current_user.id, 'identity_id' => @identity.uid}])
		gon.jobid = @jobid
		gon.account_id = current_user.id
		gon.identity_id = @identity.uid
		render :json => "OK"
	end
end

class MainWorker < Worker
	sidekiq_options :queue => :high
	
	def start(args)
		query = args['query']
		account_id = args['account_id']
		identity_id = args['identity_id']
		logger.info "MainWorker start: account_id:#{account_id} identity_id:#{identity_id}"
		s3 = AmazonS3Client.new(AWS_ACCESSKEY, AWS_SECRETKEY, AWS_REGION, S3_URL, S3_BUCKET)
		s3.s3_mass_delete("#{account_id}/#{identity_id}/")
# 		prefix = "#{account_id}:#{identity_id}"
# 
# 		Sidekiq.redis{|conn| conn.del("#{prefix}:cancel")}
# 		Sidekiq.redis{|conn| conn.del("#{prefix}:messageids")}
# 		Sidekiq.redis{|conn| conn.del("#{prefix}:attachmentids")}
# 		Sidekiq.redis{|conn| conn.del("#{prefix}:messageids_list")}
# 		Sidekiq.redis{|conn| conn.del("#{prefix}:attachmentids_list")}
	  
		logger.info "Searching messages for attachments.."
		message_ids = search_emails(query)
		puts "Found #{message_ids.count} messages"
		kickoff_grab_messages(message_ids, args)
	end
	
	def kickoff_grab_messages(message_ids, args)
		#message_array = split_arrays(message_ids, 25)
		message_ids.each do |messageid|
			args['message_ids'] = messageid
			MessageWorker.perform_async(args)
		end
	end
end
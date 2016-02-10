class MessageWorker < Worker
  def start(args)	
	message_ids = args['message_ids']
	messages = get_emails(message_ids)
	kickoff_grab_attachments(messages, args)
  end
  
	def kickoff_grab_attachments(messages, args)
		json_attachments = Array.new
		
		attachments = get_attachment_ids(messages)
		attachments.each do |attachment|
			save_redis_list("#{@account_id}:#{@identity_id}:attachmentids_list", attachment.id)
			json_attachments.push(attachment.to_json)
		end
		#attachment_array = split_arrays(json_attachments, 25)
		json_attachments.each do |attachment|
			args['attachments'] = [attachment]
			AttachmentWorker.perform_async(args)
		end
	end
end
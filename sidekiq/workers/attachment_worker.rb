class AttachmentWorker < Worker
	sidekiq_options :queue => :low

	def start(args)
		@s3 = AmazonS3Client.new(AWS_ACCESSKEY, AWS_SECRETKEY, AWS_REGION, S3_URL, S3_BUCKET)

		attachments = Array.new
		json_attachments = args['attachments']
		json_attachments.each do |attachment|
			attachments.push(AttachmentObject.from_json(attachment))
		end
		get_attachments(attachments)
		puts "Grabbed #{attachments.count} attachments"
	end
end
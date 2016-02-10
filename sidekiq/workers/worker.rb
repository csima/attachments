module GmailAPI
	attr_accessor :client, :api, :account_id, :identity_id, :s3
	
	class JobCancelException < StandardError
	end
	
	class AmazonS3Client
		attr_accessor :s3, :access_key, :secret_key, :region, :signer, :logger, :s3_bucket, :s3url, :s3client
	
		def initialize(access_key, secret_key, region, s3_url, s3_bucket)
			@access_key = access_key
			@secret_key = secret_key
			@region = region
			@s3_bucket = s3_bucket
			@s3url = s3_url
			
			if @logger.nil?
				@logger = Logger.new($stderr)
				@logger.formatter = lambda{|sev, datetime, progname, msg| "[#{sev}] #{msg}\n" }
				@logger.level = Logger::INFO
			end
			
			Aws.config = {
			    :access_key_id => @access_key,
			    :secret_access_key => @secret_key,
			    :region => @region
			}
			@s3 = Aws::S3::Resource.new(
				credentials: Aws::Credentials.new(@access_key,@secret_key),
				region: @region
			)
			@signer = Aws::S3::Presigner.new(client: @s3)
			@s3client = Aws::S3::Client.new
		end
		
		def log(message)
			puts message
			@logger.info message
		end
		
		def get(key)
			resp = @s3client.get_object(bucket:S3_BUCKET, key:key)
			return resp
		end
		
		def s3_mass_delete(s3key)
			bucket = Aws::S3::Bucket.new(client: @s3client, name: @s3_bucket)
			s3keys = bucket.objects(prefix: s3key).collect(&:key)
			if s3keys.count == 0
				return
			end
			
			new_s3keys = Array.new
			s3keys.each do |key|
				new_s3keys.push({key: key})
			end

			if new_s3keys.count > 1000
				keyarray = new_s3keys.each_slice(1000)
				keyarray.each do |array|
					resp = @s3client.delete_objects({bucket: @s3_bucket, delete: {objects: array, quiet: true}})
				end
			else
				resp = @s3client.delete_objects({bucket: @s3_bucket, delete: {objects: new_s3keys, quiet: true}})
			end

			if resp.errors.count > 0
				puts "Error in s3 mass delete: #{resp.errors}"
				raise
			end
		end

		def upload(key, content, metadata = nil)
			begin
				#log("Uploading #{File.basename(key)} to s3")
				obj = @s3.bucket(@s3_bucket).object(key)
				
				if metadata.nil?
					obj.put(body:content, acl:'public-read')
				else
					obj.put(body:content, acl:'public-read', metadata: metadata)
				end
				
				url = obj.public_url
				
				@logger.info url
				return url
			rescue Aws::S3::Errors::ServiceError => e
		  		puts e.message
		  	end
		end
		
		def upload_app(key, file)
			begin
				#filekey = File.basename(fname)

			  	log("Uploading #{key}")
			  	
			  	obj = @s3.bucket(@s3_bucket).object(key)

			  	obj.upload_file(file, acl:'public-read')
			  	url = obj.public_url

				@logger.info url
				return url
			rescue Aws::S3::Errors::ServiceError => e
		  		puts e.message
		  	end
		end
	end

	class AttachmentObject
		attr_accessor :filename, :data, :id, :message_id, :url, :date
		
		def initialize(filename, data, id, message_id, url, date)
			@filename = filename
			@data = data
			@id = id
			@message_id = message_id
			@url = url
			@date = date
		end
		
		def to_json
			JSON.dump ({
				:filename => @filename,
				:data => @data,
				:id => @id,
				:message_id => @message_id,
				:url => @url,
				:date => @date
			})
		end
		
		def self.from_json(string)
			data = JSON.load string
			self.new(data['filename'],data['data'],data['id'],data['message_id'],data['url'],data['date'])
		end
	end

	def save_attachment_to_db(attachment, account_id, identity_id)
		save_redis("#{@account_id}:#{@identity_id}:attachmentids", attachment.id,attachment.message_id)
	end
	
	def save_attachment_to_s3(attachment, account_id, identity_id)
		url = s3.upload("#{account_id}/#{identity_id}/#{attachment.filename}",attachment.data, {'date' => attachment.date, 'filename' => attachment.filename})
	end
	
	def log(data)
		puts data
	end
	
	def save_attachment(directory, attachment)
		directory = File.expand_path(directory)
		if Dir.exist?(directory) == false
			Dir.mkdir(directory)
		end
		
		begin
			filename = "#{directory}/#{attachment.filename}"
			File.write("#{filename}", attachment.data)
			
			# Set access/modification timestamp to email
			File.utime(DateTime.parse(attachment.date).to_time, DateTime.parse(attachment.date).to_time, filename)
		rescue => e
		end
	end
	
	def save_attachments(directory, attachments)
		attachments.each do |attachment|
			save_attachment(directory, attachment)
		end
	end
	
	def google_initialize(token)
		@client = Google::APIClient.new(:application_name => 'Gmail API app')
		@client.authorization.access_token = token
		@api = @client.discovered_api('gmail', 'v1')
	end
	
	def search_emails(query)
		
		messages = Array.new
		message_ids = Array.new
		
		result = @client.execute(
			:api_method => @api.users.messages.list,
			:parameters => {'userId' => 'me', 'q' => query})

		messages.push(*result.data.messages)
		result.data.messages.each do |message|
			save_redis_list("#{@account_id}:#{@identity_id}:messageids_list", message.id)
		end
		while result.response.body.include?('nextPageToken')
			check_for_cancel()
			result = @client.execute(
				:api_method => @api.users.messages.list,
				:parameters => {'userId' => 'me', 'q' => query, 'pageToken' => result.data.nextPageToken})
			messages.push(*result.data.messages)
			
			result.data.messages.each do |message|
				save_redis_list("#{@account_id}:#{@identity_id}:messageids_list", message.id)
			end
		end
				
		messages.each do |message|
			message_ids.push(message.id)
			#save_redis_list("#{@account_id}:#{@identity_id}:messageids_list", message.id)
		end

		return message_ids
	end
	
	def check_for_cancel
		Sidekiq.redis do |conn|
			result = conn.get("#{account_id}:#{identity_id}:cancel")
			if result.nil? == false
				puts "#{jid} Canceled"
				raise JobCancelException
			end
		end
	end
	
	def save_redis(phase, key, value)
		Sidekiq.redis do |conn|
			result = conn.hset(phase, key, value)
		end
	end

	def save_redis_list(key, value)
		Sidekiq.redis do |conn|
			result = conn.lpush(key, value)
		end
	end
	
	def getall_redis(hash)
		Sidekiq.redis do |conn|
			result = conn.hgetall(hash)
			if result.nil? == false
				return result
			else
				log("error in hgetall(#{hash})")
				return nil
			end
		end
	end
		
	def get_attachments(attachment)
		attachments = Array.new
		attachments.push(*attachment)
		
		attachments.each do |attachment|
			check_for_cancel()

			result = @client.execute(
			:api_method => @api.users.messages.attachments.get,
			:parameters => {'userId' => 'me', 'id' => attachment.id, 'messageId' => attachment.message_id})
			data = JSON(result.body)
			
			if data.nil?
				puts "Response from gmail failed: #{attachment.filename}"
				#raise JobCancelException
				binding.pry
			end
			
			if data['error'].nil? == false
				puts data
				binding.pry
			end 
			
			begin
				filedata = Base64.urlsafe_decode64(data['data'])
			rescue => e
				puts e
				binding.pry
			end
			
			attachment.url = result.response.env.url.to_s
			attachment.data = filedata
			
			save_attachment_to_db(attachment, @account_id, @identity_id)
			save_attachment_to_s3(attachment, @account_id, @identity_id)
			
			#save_attachment("#{ATTACHMENTS_PATH}/#{@identity_id}", attachment)
			#print " #{attachment.filename} "
		end
	end
	
	def get_gmail_attribute(gmail_data, attribute)
	  headers = gmail_data['payload']['headers']
	  array = headers.reject { |hash| hash['name'] != attribute }
	  array.first['value']
	end
	
	def save_message_to_db(messageid, account_id, identity_id, message)
		#email = Message.create(messageid: messageid, accountid: account_id, identityid: identity_id, downloaded: true, data: message)
		#email.save
		save_redis("#{account_id}:#{identity_id}:messageids", messageid, message)
	end

	def get_messagesids_from_db()
		messageids = getall_redis("#{@account_id}:#{identity_id}:messageids")
		initial_count = messageids.count

		messageids.each do |key, value|
			if value != ""
				messageids.delete(key)
			end
		end

		if initial_count > 0 && messageids.empty?
			return nil
		else
			return messageids
		end
	end
	
	def get_emails(ids)
		messages = Array.new
		emails = Array.new
		messages.push(*ids)
			
		messages.each do |id|
			check_for_cancel()

			message = @client.execute(
	      :api_method => @api.users.messages.get,
	      :parameters => {'userId' => 'me', 'id' => id})
			emails.push(message)
			
			#save_redis("test", get_gmail_attribute(message.data, 'Subject'), id)

			save_message_to_db(id, @account_id, @identity_id, "true")
			#print " #{emails.count} " if (emails.count) % 50 == 0
		end
		return emails
	end
	
	def list_labels
	  # Show the user's message list
	  result = @client.execute(
	      :api_method => @api.users.labels.list,
	      :parameters => {'userId' => 'me'})
	  labels = JSON.parse(result.body)
	  return labels
	end

	def get_email_date(email)
		email.data.payload.headers.each do |header|
			if header.name == 'Date'
				message_date = header.value
				return message_date
			end
		end
		
		return nil
	end
	
	def parse_attachment_part(part, messageid, message_date)
		begin
			attachment_id = part.body.attachmentId
		rescue => e
			attachment_id = nil
		end

		if attachment_id.nil? == false && part.filename != ""
			  attachment = AttachmentObject.new(part.filename, "", attachment_id, messageid, "",message_date)
			  #attachment.id = attachment_id
			  #attachment.filename = part.filename
			  #attachment.message_id = messageid
			  #attachment.date = message_date
			  return attachment
		else 
			return nil
		end
	end
	
	def get_attachment_ids(data)
		emails = Array.new
		attachments = Array.new

		emails.push(*data)
		emails.each do |email|
			messageid = email.data.id
			message_date = get_email_date(email)

			if email.data.payload.parts.nil? == false
				email.data.payload.parts.each do |part|
					part.parts.each do |subpart|
						attachment = parse_attachment_part(subpart, messageid, message_date)
						if attachment.nil? == false
							attachments.push(attachment)
						end
					end
					
					attachment = parse_attachment_part(part, messageid, message_date)
					if attachment.nil? == false
						attachments.push(attachment)
					end
				end
			else
				subject = get_gmail_attribute(gmail_data, 'Subject')
				puts "No attachment: Message: #{subject} id: #{messageid}"
			end
		end
		return attachments
	end
end

class Worker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  include GmailAPI

  def split_arrays(array, count)
	  count = array.count / count
	  if count == 0 
		  count = 1
	  end
	  begin
	  	result = array.each_slice(count).to_a
	  rescue => e
	  	binding.pry
	  end
	  return result
  end
  
  def perform(*args)
	  check_for_cancel
	  args = args[0]
	  command = args['command']
	  token = args['token']	  
	  @account_id = args['account_id']
	  @identity_id = args['identity_id']

	  if token.nil? || token.empty?
		  puts "TOKEN BLANK"
	  end
	  
	  google_initialize(token)
	  begin
	  	start(args)
	  rescue JobCancelException
	  	return
	  end
  end
end
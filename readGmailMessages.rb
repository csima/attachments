require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'fileutils'
require 'pry'
require 'base64'

# ##
# # Ensure valid credentials, either by restoring from the saved credentials
# # files or intitiating an OAuth2 authorization request via InstalledAppFlow.
# # If authorization is required, the user's default browser will be launched
# # to approve the request.
# #
# # @return [Signet::OAuth2::Client] OAuth2 credentials

# Need to install this 'google-api-client'
APPLICATION_NAME = 'Gmail API Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.pwd, '.credentials',"gmail-api-credentials.json")
SCOPE = 'https://mail.google.com/'
ENV['SSL_CERT_FILE'] = 'cacert.pem'

class Attachment
	attr_accessor :filename, :data, :id, :message_id, :url, :date
end

class GmailAPI
	attr_accessor :client, :api
	
	def authorize(credentials_location, client_secret_location, scope)
		FileUtils.mkdir_p(File.dirname(credentials_location))
		
		file_store = Google::APIClient::FileStore.new(credentials_location)
		storage = Google::APIClient::Storage.new(file_store)
		auth = storage.authorize
		
		if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
			app_info = Google::APIClient::ClientSecrets.load(client_secret_location)
			flow = Google::APIClient::InstalledAppFlow.new({
				:client_id => app_info.client_id,
				:client_secret => app_info.client_secret,
				:scope => scope})
			auth = flow.authorize(storage)
			puts "Credentials saved to #{credentials_location}" unless auth.nil?
		end
		auth
	end
	
	def initialize(client_secret_location)
		credentials_location = File.join(Dir.pwd, '.credentials',"gmail-api-credentials.json")
		@client = Google::APIClient.new(:application_name => 'Gmail API app')
		@client.authorization = authorize(credentials_location, client_secret_location, "https://mail.google.com")
		@api = @client.discovered_api('gmail', 'v1')
	end
	
	def search_emails(query)
		messages = Array.new
		message_ids = Array.new
		
		result = @client.execute(
			:api_method => @api.users.messages.list,
			:parameters => {'userId' => 'me', 'q' => query})
		messages.push(*result.data.messages)
	
		while result.response.body.include?('nextPageToken')
			result = @client.execute(
				:api_method => @api.users.messages.list,
				:parameters => {'userId' => 'me', 'q' => query, 'pageToken' => result.data.nextPageToken})
			messages.push(*result.data.messages)
			
		end
		
		messages.each do |message|
			message_ids.push(message.id)
		end

		return message_ids
	end
	
	def save_attachments(directory, attachments)
		directory = File.expand_path(directory)
		if Dir.exist?(directory) == false
			Dir.mkdir(directory)
		end
		
		attachments.each do |attachment|
			begin
			filename = "#{directory}/#{attachment.filename}"
			puts "Saving #{filename}"
			File.write("#{filename}", attachment.data)
			
			# Set access/modification timestamp to email
			File.utime(DateTime.parse(attachment.date).to_time, DateTime.parse(attachment.date).to_time, filename)
			rescue
			binding.pry
			end
		end
	end
	
	def get_attachments(attachment)
		attachments = Array.new
		attachments.push(*attachment)
		
		attachments.each do |attachment|
			result = @client.execute(
			:api_method => @api.users.messages.attachments.get,
			:parameters => {'userId' => 'me', 'id' => attachment.id, 'messageId' => attachment.message_id})
			data = JSON(result.body)
			filedata = Base64.urlsafe_decode64(data['data'])
			
			attachment.url = result.response.env.url.to_s
			attachment.data = filedata
		end
	end
	
	def get_gmail_attribute(gmail_data, attribute)
	  headers = gmail_data['payload']['headers']
	  array = headers.reject { |hash| hash['name'] != attribute }
	  array.first['value']
	end

	def get_emails(ids)
		messages = Array.new
		emails = Array.new
		messages.push(*ids)
		
		messages.each do |id|
			message = @client.execute(
	      :api_method => @api.users.messages.get,
	      :parameters => {'userId' => 'me', 'id' => id})
			emails.push(message)
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
			  attachment = Attachment.new()
			  attachment.id = attachment_id
			  attachment.filename = part.filename
			  attachment.message_id = messageid
			  attachment.date = message_date
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

# search for attachments in a 2 week window by going backwards starting from current date
def rotate_dates(attachment_limit)
	attachments = Array.new
	finished = false
	before_date = Date.today
	after_date = before_date - 14
	while finished == false
		query_after_date = "after:#{after_date.year}/#{after_date.month}/#{after_date.day}"
		query_before_date = "before:#{before_date.year}/#{before_date.month}/#{before_date.day}"
		query = "has:attachment #{query_after_date} #{query_before_date}"
		puts query
		# Do query
		attachments.push(*grab_attachments(query))
		if attachments.count > attachment_limit
			finished = true
		end

		before_date = after_date
		after_date = before_date - 14
		sleep(1)
	end
	
	return attachments
end

def grab_attachments(query)
	gmail = GmailAPI.new(CLIENT_SECRETS_PATH)
	message_ids = gmail.search_emails(query)
	puts "Grabbed #{message_ids.count} message_ids"
	binding.pry
	emails = gmail.get_emails(message_ids.last(50))
	puts "Grabbed #{emails.count} emails"
	attachment_ids = gmail.get_attachment_ids(emails)
	puts "Grabbed #{attachment_ids.count} attachment_ids"
	attachments = gmail.get_attachments(attachment_ids)
	puts "Grabbed #{attachments.count} attachments"
	gmail.save_attachments("./tmp", attachments)
end

#attachments = rotate_dates(250)
grab_attachments("has:attachment")
#gmail = GmailAPI.new(CLIENT_SECRETS_PATH)
#emails = gmail.get_emails("13816a339fa54843")
#gmail.get_attachment_ids(emails)
CLIENT_ID = "409109378675-2lgid8tu7fcr62bal2pdue9tf9uqs8f0.apps.googleusercontent.com"
CLIENT_SECRET = "0eiUww4KlUW0uPhv2UG2WJ14"

	      
binding.pry
require 'aws-sdk'
require 'pry'
require 'fileutils'

class S3DownloadControllerWorker
	include Sidekiq::Worker
	include Sidekiq::Status::Worker
		
	def perform(*args)
		args = args[0]
		account_id = args['account_id']
		identity_id = args['identity_id']
		redis_prefix = "#{account_id}:#{identity_id}"

		Sidekiq.redis{|conn| conn.del("#{redis_prefix}:zip:list")}
		Sidekiq.redis{|conn| conn.del("#{redis_prefix}:zip:list_complete")}

		s3 = AmazonS3Client.new(AWS_ACCESSKEY, AWS_SECRETKEY, AWS_REGION, S3_URL, S3_BUCKET)
		bucket = Aws::S3::Bucket.new(client: s3.s3client, name:S3_BUCKET)
		s3keys = bucket.objects(prefix: "#{account_id}/#{identity_id}/").collect(&:key)
		
		Sidekiq.redis{|conn| conn.set("#{redis_prefix}:zip:list_total", s3keys.count)}

		s3keys.each do |key|
			args['key'] = key
			args['jobcount'] = s3keys.count
			S3DownloadWorker.perform_async(args)
		end
	end
end

class S3DownloadWorker
	include Sidekiq::Worker
	include Sidekiq::Status::Worker
	
	def perform(*args)
		args = args[0]
		key = args['key']
		account_id = args['account_id']
		identity_id = args['identity_id']
		jobcount = args['jobcount']
		redis_prefix = "#{account_id}:#{identity_id}"
		
		s3 = AmazonS3Client.new(AWS_ACCESSKEY, AWS_SECRETKEY, AWS_REGION, S3_URL, S3_BUCKET)
		directory = "#{account_id}/#{identity_id}/"
		filename = key.sub(directory,'')
		
		FileUtils::mkdir_p directory unless File.exists?(directory)
		begin
			resp = s3.s3client.get_object(bucket:S3_BUCKET, key:key, response_target:"#{account_id}/#{identity_id}/#{filename}")
			timestamp = resp.metadata['date']
			# Set access/modification timestamp to email
			File.utime(DateTime.parse(timestamp).to_time, DateTime.parse(timestamp).to_time, "#{account_id}/#{identity_id}/#{filename}")
		rescue => e
			logger.error "Something went wrong when trying to retrieve a file from s3: (key)#{key} #{e}"
		end
		
		Sidekiq.redis{|conn| conn.lpush("#{redis_prefix}:zip:list",key)}
		jobs_completed = Sidekiq.redis{|conn| conn.llen("#{redis_prefix}:zip:list")}
		if jobs_completed == jobcount
			puts "Download from s3 complete"
			Sidekiq.redis{|conn| conn.set("#{redis_prefix}:zip:list_complete",true)}
		end
	end
end

class AmazonS3Client
		attr_accessor :s3, :access_key, :secret_key, :region, :signer, :s3_bucket, :s3url, :s3client
	
		def initialize(access_key, secret_key, region, s3_url, s3_bucket)
			@access_key = access_key
			@secret_key = secret_key
			@region = region
			@s3_bucket = s3_bucket
			@s3url = s3_url
			
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
		
		def upload(key, content, metadata = nil)
			begin
				obj = @s3.bucket(@s3_bucket).object(key)
				
				if metadata.nil?
					obj.put(body:content, acl:'public-read')
				else
					obj.put(body:content, acl:'public-read', metadata: metadata)
				end
				
				url = obj.public_url
				
				return url
			rescue Aws::S3::Errors::ServiceError => e
		  		puts e.message
		  	end
		end

end


require 'pty'
require 'aws-sdk'
require 'pry'
require 'fileutils'
require 'filesize'

class CompressWorker
	include Sidekiq::Worker
	include Sidekiq::Status::Worker
	
	def perform(*args)
		args = args[0]
		start(args)
	end
	
  def start(args)
  	identity_id = args['identity_id']
  	account_id = args['account_id']
  	
  	folder = "#{account_id}/#{identity_id}"
	puts "Compress Worker!"  
	cmd = "cd #{account_id};tar -c #{identity_id} --remove-files | pv -n --size `du -cshm #{identity_id} | grep total | cut -f1`m | pigz > #{identity_id}.tgz" 
	#cmd = "cd #{account_id};tar -c #{identity_id} | pv -n --size `du -cshm #{identity_id} | grep total | cut -f1`m | pigz > #{identity_id}.tgz" 

	begin
	  PTY.spawn( cmd ) do |stdout, stdin, pid|
	    begin
	      # Do stuff with the output here. Just printing to show it works
	      stdout.each do |line|
	      	print line
	      	percent = line.to_i
	      	at percent, "#{percent}% complete"
	      end
	    rescue Errno::EIO
	      puts "Errno:EIO error, but this probably just means " +
	            "that the process has finished giving output"
	    end
	  end
	rescue PTY::ChildExited
	  puts "The child process exited!"
	end
	
	zip_location = "#{account_id}/#{identity_id}.tgz"
	filesize = "#{File.size(zip_location)} B"
	puts "Upload #{folder}/#{identity_id}.tgz to s3 size:#{Filesize.from(filesize).pretty}"
	s3 = AmazonS3Client.new(AWS_ACCESSKEY, AWS_SECRETKEY, AWS_REGION, S3_URL, S3_BUCKET)
	url = s3.upload_app("#{folder}/#{identity_id}.tgz",File.expand_path("#{account_id}/#{identity_id}.tgz"))
	at 100, url
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
		
		def upload_app(key, file)
			begin
				#filekey = File.basename(fname)			  	
			  	obj = @s3.bucket(@s3_bucket).object(key)
			  	obj.upload_file(file, acl:'public-read')
			  	url = obj.public_url

				return url
			rescue Aws::S3::Errors::ServiceError => e
		  		puts e.message
		  	end
		end

end
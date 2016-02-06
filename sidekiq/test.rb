require 'aws-sdk'
require 'logger'
require 'pry'
require 'redis'
require 'sidekiq'

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
  
  def s3_mass_delete(s3key)
	s3 = Aws::S3::Client.new
	bucket = Aws::S3::Bucket.new(client: s3, name:S3_BUCKET)
	s3keys = bucket.objects(prefix: s3key).collect(&:key)
	new_s3keys = Array.new
	s3keys.each do |key|
		new_s3keys.push({key: key})
	end

	if new_s3keys.count > 1000
		keyarray = new_s3keys.each_slice(1000)
		keyarray.each do |array|
			resp = s3.delete_objects({bucket: S3_BUCKET, delete: {objects: array, quiet: true}})
		end
	else
		resp = s3.delete_objects({bucket: S3_BUCKET, delete: {objects: new_s3keys, quiet: true}})
	end
end

# S3_URL = "https://attachments.storage.s3-website-us-west-1.amazonaws.com"
S3_BUCKET = "attachments.storage"
AWS_ACCESSKEY = "AKIAJAFC5GYPZA6E3RYQ"
AWS_SECRETKEY = "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"
AWS_REGION = "us-west-1"
redis = Redis.new(:host => "127.0.0.1", :port => 6379)

		Aws.config = {
		    :access_key_id => AWS_ACCESSKEY,
		    :secret_access_key => AWS_SECRETKEY,
		    :region => AWS_REGION
		}

account_id = "1"
identity_id = "111540876854114855740"
s3 = Aws::S3::Client.new
bucket = Aws::S3::Bucket.new(client: s3, name:S3_BUCKET)



binding.pry

# #redis.lpush("#{account_id}:#{identity_id}:zip:list", s3keys)
# key = '1/111540876854114855740/AoD - Intro to HP April 2009.pdf'
# filename = key.sub("#{account_id}/#{identity_id}/",'')
# resp = s3.get_object(bucket:S3_BUCKET, key:'1/111540876854114855740/AoD - Intro to HP April 2009.pdf', response_target:"#{account_id}/#{identity_id}/#{filename}")
# timestamp = resp.metadata['date']
# File.utime(DateTime.parse(timestamp).to_time, DateTime.parse(timestamp).to_time, "#{account_id}/#{identity_id}/#{filename}")

binding.pry

require 'aws-sdk'
require 'pry'

S3_URL = "https://attachments.storage.s3-website-us-west-1.amazonaws.com"
S3_BUCKET = "attachments.storage"
AWS_ACCESSKEY = "AKIAJAFC5GYPZA6E3RYQ"
AWS_SECRETKEY = "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"
AWS_REGION = "us-west-1"

Aws.config = {
    :access_key_id => AWS_ACCESSKEY,
    :secret_access_key => AWS_SECRETKEY,
    :region => AWS_REGION
}

s3 = Aws::S3::Client.new
bucket = Aws::S3::Bucket.new(client: s3, name:S3_BUCKET)
#bucket.objects.each do |object|
#	puts object.key
#	puts object.object.metadata
#end
#binding.pry

bucket.objects(prefix: '1/111540876854114855740/').each do |object|
	puts object.key
	binding.pry
end
#result = bucket.objects(prefix: '1/111540876854114855740/').collect(&:key)

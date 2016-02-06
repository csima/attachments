require 'pty'

class CompressWorker < Worker
  def start(args)
  	identity_id = args['identity_id']
  	account_id = args['account_id']
  	
  	folder = "#{account_id}/#{identity_id}"
	puts "Compress Worker!"  
	cmd = "cd #{account_id};tar -c #{identity_id} | pv -n --size `du -cshm #{identity_id} | grep total | cut -f1`m | pigz > #{identity_id}.tgz" 
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
	
	s3 = AmazonS3Client.new(AWS_ACCESSKEY, AWS_SECRETKEY, AWS_REGION, S3_URL, S3_BUCKET)
	url = s3.upload_app("#{folder}/#{identity_id}.tgz",File.expand_path("#{account_id}/#{identity_id}.tgz"))
	at 100, url
  end
end
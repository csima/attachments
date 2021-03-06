class Identity < ActiveRecord::Base
  belongs_to :user

  def self.find_with_omniauth(auth)
    find_by(uid: auth['uid'], provider: auth['provider'])
  end

  def self.create_with_omniauth(auth)
    create(uid: auth['uid'], provider: auth['provider'])
  end
  
  def to_params
    {'refresh_token' => refresh_token,
    'client_id' => ENV['GOOGLE_CLIENT_ID'],
    'client_secret' => ENV['GOOGLE_CLIENT_SECRET'],
    'grant_type' => 'refresh_token'}
  end

  def request_token_from_google
	  logger.info "Requesting token from google: #{self.to_params}"
    url = URI("https://accounts.google.com/o/oauth2/token")
    Net::HTTP.post_form(url, self.to_params)
  end

  def refresh!
    response = request_token_from_google
    data = JSON.parse(response.body)
	#binding.pry
    if data['error'].nil? == false
	    error = "error: Refresh token failed! #{data}"
	    puts error
	    
	    if data['error'] == "unauthorized_client"
		    puts "Removing refresh_token"
		    self.refresh_token = ""
		    self.save
		end
		
	    raise error
	end
	
    update_attributes(
    access_token: data['access_token'],
    expires: Time.now + (data['expires_in'].to_i).seconds)
  end

  def expired?
    expires < Time.now
  end

  def fresh_token
    refresh! if expired?
    access_token
  end
end
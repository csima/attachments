class SessionsController < ApplicationController
    layout false

	def create
		logger.info "Create Session: #{request.env['omniauth.auth']}"
		
		auth = request.env['omniauth.auth']
	# Find an identity here
	  @identity = Identity.find_with_omniauth(auth)

	  if @identity.nil?
	    # If no identity was found, create a brand new one here
	    #@identity = Identity.create_with_omniauth(auth)
	    @identity = create_identity(auth)
	  end
	
	  if signed_in?
		  logger.info "User is signed in. #{current_user}"
	    if @identity.user == current_user
	      # User is signed in so they are trying to link an identity with their
	      # account. But we found the identity and the user associated with it 
	      # is the current user. So the identity is already associated with 
	      # this user. So let's display an error message.
	      redirect_to root_url, notice: "Already linked that account!"
	    else
	    	logger.info "Adding new identity to account"
	      # The identity is not associated with the current_user so lets 
	      # associate the identity
	      @identity.user = current_user
	      @identity.save()
	      redirect_to root_url, notice: "Successfully linked that account!"
	    end
	  else
	    if @identity.user.present?
	      # The identity we found had a user associated with it so let's 
	      # just log them in here
	      logger.info "Identity found with associated user. #{@identity.inspect}"
	      refresh_token = auth["credentials"]["refresh_token"]
	      if refresh_token.nil? == false || refresh_token.blank? == false
		      logger.info "Found new refresh_token. Updating account with refresh_token #{refresh_token}"
	      	@identity.refresh_token = refresh_token
	      	@identity.save
	      	logger.info "Identity is now: #{@identity.inspect}"
     	  end
	      
	      self.current_user = @identity.user
	      redirect_to "/home", notice: "Signed in!"
	    else
	      # No user associated with the identity so we need to create a new one
	      #redirect_to new_user_url, notice: "Please finish registering"
	      logger.info "No user associated with the identity so we need to create a new one"
	      create_user(auth)
	      @identity.user = current_user
	      @identity.save()
	    end
	  end
	end

  def create_identity(auth)
	  logger.info "Creating Identity: #{auth}"
    identity = Identity.where(:provider => auth["provider"], :uid => auth["uid"]).first_or_initialize(
      :refresh_token => auth["credentials"]["refresh_token"],
      :access_token => auth["credentials"]["token"],
      :expires => Time.at(auth['credentials']['expires_at']).to_datetime,
      :name => auth["info"]["name"],
      :email => auth["info"]["email"]
    )

    if identity.save
    	return identity
    else
    	raise "Unable to create identity"
    	return nil
    end
  end

  def create_user(auth)
	  logger.info "Creating user: #{auth}"
	user = User.create_with_omniauth(auth)  
    url = session[:return_to] || root_path
    session[:return_to] = nil
    url = root_path if url.eql?('/logout')

    if user.save
      session[:user_id] = user.id
      notice = "Signed in!"
      #logger.debug "URL to redirect to: #{url}"
      redirect_to url, :notice => notice
    else
      raise "Failed to login"
    end
  end
  
  def destroy
    session[:user_id] = nil
    redirect_to root_url, :notice => "Signed out!"
  end

  def test
	@env = request.env['omniauth.auth']
    @auth = request.env['omniauth.auth']['credentials']
    Token.create(
	  email: request.env['omniauth.auth']['info']['email'],
      access_token: @auth['token'],
      refresh_token: @auth['refresh_token'],
      expires_at: Time.at(@auth['expires_at']).to_datetime)
  end
end

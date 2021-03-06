class ClearanceTwitter::TwitterUsersController < ApplicationController
  def new
    oauth_callback = request.protocol + request.host_with_port + ClearanceTwitter.oauth_callback
    @request_token = ClearanceTwitter.consumer.get_request_token({:oauth_callback=>oauth_callback})
    session[:request_token] = @request_token.token
    session[:request_token_secret] = @request_token.secret
    redirect_to @request_token.authorize_url
  end

  def oauth_callback
    unless session[:request_token] && session[:request_token_secret] 
      deny_access('No authentication information was found in the session. Please try again.') and return
    end

    unless params[:oauth_token].blank? || session[:request_token] ==  params[:oauth_token]
      deny_access('Authentication information does not match session information. Please try again.') and return
    end

    @request_token = OAuth::RequestToken.new(ClearanceTwitter.consumer, session[:request_token], session[:request_token_secret])

    oauth_verifier = params["oauth_verifier"]
    @access_token = @request_token.get_access_token(:oauth_verifier => oauth_verifier)

    # The request token has been invalidated
    # so we nullify it in the session.
    session[:request_token] = nil
    session[:request_token_secret] = nil

    if current_user
      current_user.update_from_twitter_access_token(@access_token)
    else
      @user = User.identify_or_create_from_access_token(@access_token)
      sign_in(@user)
    end

    flash_success_after_callback
    redirect_to url_after_callback
  rescue Net::HTTPServerException => e
    case e.message
    when '401 "Unauthorized"'
      deny_access('This authentication request is no longer valid. Please try again.') and return
    else
      deny_access('There was a problem trying to authenticate you. Please try again.') and return
    end 
  rescue OAuth::Unauthorized => e
    deny_access('There was a problem trying to authenticate you. Please try again.') and return
  end

  private

  def url_after_callback
    root_url
  end

  def flash_success_after_callback
    flash[:success] = "Successfully signed in with Twitter."
  end

end

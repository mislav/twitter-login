require 'oauth'
require 'yajl'
require 'rack/request'
require 'hashie/mash'

module Twitter
end

class Twitter::Login
  attr_reader :options
  
  class << self
    attr_accessor :consumer_key, :secret, :site
  end
  
  DEFAULTS = {
    :return_to => '/',
    :site => 'http://api.twitter.com',
    :authorize_path => '/oauth/authenticate'
  }
  
  def initialize(options)
    @options = DEFAULTS.merge options
    self.class.consumer_key, self.class.secret = @options[:consumer_key], @options[:secret]
    self.class.site = @options[:site]
  end
  
  def login_handler(options = {})
    @options.update options
    return self
  end
  
  def call(env)
    request = Request.new(env)
  
    if request[:oauth_verifier]
      # user authorized the app
      handle_twitter_authorization(request)
    elsif request[:denied]
      # user refused to log in with Twitter
      handle_denied_access(request)
    else
      # starting the login process; send user to Twitter
      redirect_to_twitter(request)
    end
  end
  
  module Helpers
    def twitter_client
      OAuth::AccessToken.new(twitter_oauth, *session[:twitter_access_token])
    end
    
    def twitter_oauth
      OAuth::Consumer.new Twitter::Login.consumer_key, Twitter::Login.secret,
        :site => Twitter::Login.site
    end
    
    def twitter_user
      if session[:twitter_user]
        Hashie::Mash[session[:twitter_user]]
      end
    end
    
    def twitter_logout
      [:twitter_access_token, :twitter_user].each do |key|
        session[key] = nil # work around a Rails 2.3.5 bug
        session.delete key
      end
    end
  end
  
  class Request < Rack::Request
    # for storing :request_token, :access_token
    def session
      env['rack.session'] ||= {}
    end
    
    # SUCKS: must duplicate logic from the `url` method
    def url_for(path)
      url = scheme + '://' + host

      if scheme == 'https' && port != 443 ||
          scheme == 'http' && port != 80
        url << ":#{port}"
      end

      url << path
    end
    
    def xhr?
      !(env['HTTP_X_REQUESTED_WITH'] !~ /XMLHttpRequest/i)
    end
    
    def wants?(mime_type)
      env['HTTP_ACCEPT'].to_s.include? mime_type
    end
  end
  
  protected
  
  def redirect_to_twitter(request)
    # create a request token and store its parameter in session
    request_token = oauth.get_request_token(:oauth_callback => request.url)
    request.session[:twitter_request_token] = [request_token.token, request_token.secret]
    
    # redirect to Twitter authorization page
    if request.wants? 'application/json'
      body = %({"authorize_url":"#{request_token.authorize_url}"})
      ["200", {'Content-type' => 'application/json'}, [body]]
    elsif request.xhr? or request.wants? 'application/javascript'
      body = "window.location.assign('#{request_token.authorize_url}')"
      ["200", {'Content-type' => 'application/javascript'}, [body]]
    else
      redirect request_token.authorize_url
    end
  end
  
  def handle_twitter_authorization(request)
    access_token = authorize_from_request(request)
    
    # get and store authenticated user's info from Twitter
    response = access_token.get('/1/account/verify_credentials.json')
    request.session[:twitter_user] = user_hash_from_response(response)
    
    redirect_to_return_path(request)
  end
  
  def handle_denied_access(request)
    # cleanup session and set an error identifier
    request.session[:twitter_request_token] = nil # work around a Rails 2.3.5 bug
    request.session.delete(:twitter_request_token)
    request.session[:twitter_error] = 'user_denied'
    redirect_to_return_path(request)
  end
  
  private
  
  # replace the request token in session with access token
  def authorize_from_request(request)
    rtoken, rsecret = request.session[:twitter_request_token]
    request_token = OAuth::RequestToken.new(oauth, rtoken, rsecret)
    
    request_token.get_access_token(:oauth_verifier => request[:oauth_verifier]).tap do |access_token|
      request.session.delete(:twitter_request_token)
      request.session[:twitter_access_token] = [access_token.token, access_token.secret]
    end
  end
  
  def redirect_to_return_path(request)
    redirect request.url_for(options[:return_to])
  end
  
  def redirect(url)
    ["302", {'Location' => url, 'Content-type' => 'text/plain'}, []]
  end
  
  def oauth
    OAuth::Consumer.new options[:consumer_key], options[:secret],
      :site => options[:site], :authorize_path => options[:authorize_path]
  end
  
  def user_hash_from_response(api_response)
    parse_response(api_response).reject { |key, _|
      key == 'status' or key =~ /^profile_|_color$/
    }
  end
  
  def parse_response(api_response)
    Yajl::Parser.parse api_response.body
  end
end

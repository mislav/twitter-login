require 'oauth'
require 'yajl'
require 'rack/request'
require 'hashie/mash'

module Twitter
end

class Twitter::Login
  attr_reader :options
  
  class << self
    attr_accessor :consumer_key, :secret
  end
  
  DEFAULTS = { :login_path => '/login', :return_to => '/' }
  
  def initialize(app, options)
    @app = app
    @options = DEFAULTS.merge options
    self.class.consumer_key, self.class.secret = @options[:consumer_key], @options[:secret]
  end
  
  def call(env)
    request = Request.new(env)
    
    if request.get? and request.path == options[:login_path]
      @oauth = nil
      # detect if Twitter redirected back here
      if request[:oauth_verifier]
        handle_twitter_authorization(request) do
          @app.call(env)
        end
      elsif request[:denied]
        # user refused to log in with Twitter, so give up
        handle_denied_access(request)
      else
        # user clicked to login; send them to Twitter
        redirect_to_twitter(request)
      end
    else
      @app.call(env)
    end
  end
  
  module Helpers
    def twitter_client
      OAuth::AccessToken.new(twitter_oauth, *session[:twitter_access_token])
    end
    
    def twitter_oauth
      OAuth::Consumer.new Twitter::Login.consumer_key, Twitter::Login.secret,
        :site => 'http://api.twitter.com'
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
  end
  
  protected
  
  def redirect_to_twitter(request)
    # create a request token and store its parameter in session
    request_token = oauth.get_request_token(:oauth_callback => request.url)
    request.session[:twitter_request_token] = [request_token.token, request_token.secret]
    # redirect to Twitter authorization page
    redirect request_token.authorize_url
  end
  
  def handle_twitter_authorization(request)
    access_token = authorize_from_request(request)
    response = access_token.get('/1/account/verify_credentials.json')
    
    # get and store authenticated user's info from Twitter
    request.session[:twitter_user] = user_hash_from_response(response)
    
    # pass the request down to the main app
    response = begin
      yield
    rescue
      raise unless $!.class.name == 'ActionController::RoutingError'
      [404]
    end
    
    # check if the app implemented anything at :login_path
    if response[0].to_i == 404
      # if not, redirect to :return_to path
      redirect_to_return_path(request)
    else
      # use the response from the app without modification
      response
    end
  end
  
  def handle_denied_access(request)
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
    access_token = request_token.get_access_token(:oauth_verifier => request[:oauth_verifier])
    
    request.session.delete(:twitter_request_token)
    request.session[:twitter_access_token] = [access_token.token, access_token.secret]
    return access_token
  end
  
  def redirect_to_return_path(request)
    redirect request.url_for(options[:return_to])
  end
  
  def redirect(url)
    ["302", {'Location' => url, 'Content-type' => 'text/plain'}, []]
  end
  
  def oauth
    @oauth ||= OAuth::Consumer.new(options[:consumer_key], options[:secret],
      :site => 'http://api.twitter.com',
      :authorize_path => '/oauth/authenticate'
    )
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

require 'twitter/login'
require 'rack/mock'
require 'rack/utils'
require 'rack/session/cookie'
require 'rack/builder'

require 'fakeweb'
FakeWeb.allow_net_connect = false

describe Twitter::Login do
  before(:all) do
    @app ||= begin
      main_app = lambda { |env|
        request = Rack::Request.new(env)
        if request.path == '/'
          ['200 OK', {'Content-type' => 'text/plain'}, ["Hello world"]]
        else
          ['404 Not Found', {'Content-type' => 'text/plain'}, ["Nothing here"]]
        end
      }
      
      builder = Rack::Builder.new
      builder.use Rack::Session::Cookie
      builder.use described_class, :key => 'abc', :secret => '123'
      builder.run main_app
      builder.to_app
    end
  end
  
  before(:each) do
    @request = Rack::MockRequest.new(@app)
  end
  
  it "should login with Twitter" do
    consumer = mock_oauth_consumer('OAuth Consumer')
    token = mock('Request Token', :authorize_url => 'http://disney.com/oauth', :token => 'abc', :secret => '123')
    consumer.should_receive(:get_request_token).with(:oauth_callback => 'http://example.org/login').and_return(token)
    # request.session[:request_token] = token
    # redirect token.authorize_url
    
    get('/login', :lint => true)
    response.status.should == 302
    response['Location'].should == 'http://disney.com/oauth'
    response.body.should be_empty
    session[:request_token].should == ['abc', '123']
  end
  
  it "should authorize with Twitter" do
    consumer = mock_oauth_consumer('OAuth Consumer', :key => 'con', :secret => 'sumer', :options => {:one=>'two'})
    request_token = mock('Request Token')
    OAuth::RequestToken.should_receive(:new).with(consumer, 'abc', '123').and_return(request_token)
    access_token = mock('Access Token', :token => 'access1', :secret => '42', :consumer => consumer)
    request_token.should_receive(:get_access_token).with(:oauth_verifier => 'abc').and_return(access_token)
    
    twitter = mock('Twitter Base')
    Twitter::Base.should_receive(:new).with(access_token).and_return(twitter)
    user_credentials = Hashie::Mash.new :screen_name => 'faker',
      :name => 'Fake Jr.', :profile_image_url => 'http://disney.com/mickey.png',
      :followers_count => '13', :friends_count => '6', :statuses_count => '52'
    twitter.should_receive(:verify_credentials).and_return(user_credentials)
    
    session_data = {:request_token => ['abc', '123']}
    get('/login?oauth_verifier=abc', build_session(session_data).update(:lint => true))
    response.status.should == 302
    response['Location'].should == 'http://example.org/'
    session[:request_token].should be_nil
    session[:access_token].should == ['access1', '42']
    session[:oauth_consumer].should == ['con', 'sumer', {:one => 'two'}]
    
    current_user = session[:twitter_user]
    current_user['screen_name'].should == 'faker'
  end
  
  protected
  
  [:get, :post, :put, :delete, :head].each do |method|
    class_eval("def #{method}(*args) @response = @request.#{method}(*args) end")
  end
  
  def response
    @response
  end
  
  def session
    @session ||= begin
      escaped = response['Set-Cookie'].match(/\=(.+?);/)[1]
      cookie_load Rack::Utils.unescape(escaped)
    end
  end
  
  private
  
  def build_session(data)
    encoded = cookie_dump(data)
    { 'HTTP_COOKIE' => Rack::Utils.build_query('rack.session' => encoded) }
  end
  
  def cookie_load(encoded)
    decoded = encoded.unpack('m*').first
    Marshal.load(decoded)
  end
  
  def cookie_dump(obj)
    [Marshal.dump(obj)].pack('m*')
  end
  
  def mock_oauth_consumer(*args)
    consumer = mock(*args)
    OAuth::Consumer.should_receive(:new).and_return(consumer)
    # .with(instance_of(String), instance_of(String),
    # :site => 'http://twitter.com', :authorize_path => '/oauth/authenticate')
    consumer
  end
end

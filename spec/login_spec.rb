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
      builder.use described_class, :consumer_key => 'abc', :secret => '123'
      builder.run main_app
      builder.to_app
    end
  end
  
  before(:each) do
    @request = Rack::MockRequest.new(@app)
  end
  
  it "should expose consumer key/secret globally" do
    Twitter::Login.consumer_key.should == 'abc'
    Twitter::Login.secret.should == '123'
  end
  
  it "should ignore normal requests" do
    get('/', :lint => true)
    response.status.should == 200
    response.body.should == 'Hello world'
  end
  
  it "should login with Twitter" do
    request_token = mock('Request Token', :authorize_url => 'http://disney.com/oauth', :token => 'abc', :secret => '123')
    oauth = mock_oauth('Twitter OAuth', :request_token => request_token)
    oauth.should_receive(:set_callback_url).with('http://example.org/login')
    
    get('/login', :lint => true)
    response.status.should == 302
    response['Location'].should == 'http://disney.com/oauth'
    response.body.should be_empty
    session[:request_token].should == ['abc', '123']
  end
  
  it "should authorize with Twitter" do
    consumer = mock('OAuth consumer')
    access_token = mock('Access Token', :token => 'access1', :secret => '42')
    oauth = mock_oauth('Twitter OAuth', :access_token => access_token, :consumer => consumer)
    oauth.should_receive(:authorize_from_request).with('abc', '123', 'allrighty')
    
    twitter = mock('Twitter Base')
    Twitter::Base.should_receive(:new).with(oauth).and_return(twitter)
    
    twitter.should_receive(:verify_credentials).and_return {
      Hashie::Mash.new :screen_name => 'faker',
        :name => 'Fake Jr.', :profile_image_url => 'http://disney.com/mickey.png',
        :followers_count => '13', :friends_count => '6', :statuses_count => '52'
    }
    
    session_data = {:request_token => ['abc', '123']}
    get('/login?oauth_verifier=allrighty', build_session(session_data).update(:lint => true))
    response.status.should == 302
    response['Location'].should == 'http://example.org/'
    session[:request_token].should be_nil
    session[:access_token].should == ['access1', '42']
    session[:oauth_consumer].should be_nil
    
    current_user = session[:twitter_user]
    current_user['screen_name'].should == 'faker'
  end
  
  it "should handle denied access" do
    session_data = {:request_token => ['abc', '123']}
    get('/login?denied=OMG', build_session(session_data).update(:lint => true))
    response.status.should == 302
    response['Location'].should == 'http://example.org/'
    session[:request_token].should be_nil
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
  
  def mock_oauth(*args)
    consumer = mock(*args)
    Twitter::OAuth.should_receive(:new).and_return(consumer)
    consumer
  end
end

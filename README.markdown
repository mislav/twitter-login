Drop-in login functionality for your webapp
===========================================

Mount this Rack endpoint in your web application to enable user logins through Twitter.

Check out the sister project, ["facebook-login"][facebook].

How to use
----------

First, [register a new Twitter application][register] (if you haven't already). Check
the <i>"Yes, use Twitter for login"</i> option. You can put anything as <i>"Callback
URL"</i> since the real callback URL is provided dynamically, anyway. Note down your
OAuth consumer key and secret.

You have to require 'twitter/login' in your app. If you're using Bundler:

    ## Gemfile
    gem 'twitter-login', '~> 0.4.1', :require => 'twitter/login'

Now mount the Rack endpoint in your application. In **Rails 3** this would be:

    ## application.rb:
    config.twitter_login = Twitter::Login.new \
      :consumer_key => 'CONSUMER_KEY', :secret => 'SECRET'
    
    
    ## routes.rb
    twitter = YourApp::Application.config.twitter_login
    twitter_endpoint = twitter.login_handler(:return_to => '/')
    
    mount twitter_endpoint => 'login', :as => :login
    
    
    ## application_controller.rb
    include Twitter::Login::Helpers
    
    def logged_in?
      !!session[:twitter_user]
    end
    helper_method :logged_in?
    

Fill in the `:consumer_key`, `:secret` placeholders with real values. You're done.

It is less trivial to mount a Rack endpoint in **Rails 2** or Sinatra.
This library was once Rack *middleware*, and if you prefer to use that, install the 0.3.x
version and [check out the "middleware-0.3" branch][middleware].


What it does
------------

The user will first get redirected to Twitter to approve your application. After that he
or she is redirected back to your app with an OAuth verifier GET parameter. Then, the
authenticating user is identified, this info is saved to session and the user is sent back
to the root path of your website.


Configuration
-------------

Available options for `Twitter::Login` are:

* `:consumer_key` -- OAuth consumer key *(required)*
* `:secret` -- OAuth secret *(required)*
* `:site` -- the API endpoint that is used (default: "http://api.twitter.com")
* `:return_to` -- where user goes after login (default: "/")


Helpers
-------

The `Twitter::Login::Helpers` module (for Sinatra, Rails) adds these methods to your app:

* `twitter_user` (Hashie::Mash) -- Info about authenticated user. Check this object to
  know whether there is a currently logged-in user. Access user data like `twitter_user.screen_name`
* `twitter_logout` -- Erases info about Twitter login from session, effectively logging-out the Twitter user
* `twitter_client` (OAuth::AccessToken) -- A consumer token able to query the API, e.g. `twitter_client.get('/1/path')`


Apps that use "twitter-login"
-----------------------------

* [The Movie App][movieapp] ([source code](https://github.com/mislav/movieapp))
  * [config/application.rb](https://github.com/mislav/movieapp/blob/b8f6bd9/config/application.rb#L48-49)
  * [config/routes.rb](https://github.com/mislav/movieapp/blob/b8f6bd9/config/routes.rb#L18-23)
  * [application_controller.rb](https://github.com/mislav/movieapp/blob/b8f6bd9/app/controllers/application_controller.rb#L4-43)
  * [sessions_controller.rb](https://github.com/mislav/movieapp/blob/b8f6bd9/app/controllers/sessions_controller.rb#L11-32)
* [Todas Listas][todo] ([source code](https://github.com/ivana/todofrenzy))

[register]: http://twitter.com/apps/new
[middleware]: https://github.com/mislav/twitter-login/tree/middleware-0.3#readme
[movieapp]: http://movi.im/
[todo]: http://todaslistas.heroku.com/
[facebook]: https://github.com/mislav/facebook#readme

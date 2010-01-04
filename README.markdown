Drop-in login functionality for your webapp
===========================================

Drop this Rack middleware in your web application to enable user logins through Twitter.


How to use
----------

First, [register a new Twitter application][register] (if you haven't already). Check
the <i>"Yes, use Twitter for login"</i> option. You can put anything as <i>"Callback
URL"</i> since the real callback URL is provided dynamically, anyway. Note down your
OAuth consumer key and secret.

Next, install this library:

    [sudo] gem install twitter-login

You have to require 'twitter/login' in your app. If you're using Bundler:

    ## Gemfile
    clear_sources
    source 'http://gemcutter.org'
    gem 'twitter-login', :require_as => 'twitter/login'

Now configure your app to use the middleware. This might be different across web
frameworks.

    ## Sinatra
    enable :sessions
    use Twitter::Login, :consumer_key => 'KEY', :secret => 'SECRET'
    helpers Twitter::Login::Helpers
    
    ## Rails
    # environment.rb:
    config.middleware.use Twitter::Login, :consumer_key => 'KEY', :secret => 'SECRET'
    
    # application_controller.rb
    include Twitter::Login::Helpers

Fill in the `:consumer_key`, `:secret` placeholders with real values. You're done.


What it does
------------

This middleware handles GET requests to "/login" resource of your app. Make a login
link that points to "/login" and you're all set to receive logins from Twitter.

The user will first be redirected to Twitter to approve your application. After that he
or she is redirected back to "/login" with an OAuth verifier GET parameter. The
middleware then identifies the authenticating user, saves this info to session and
redirects to the root of your website.


Configuration
-------------

Available options for `Twitter::Login` middleware are:

* `:consumer_key` -- OAuth consumer key *(required)*
* `:secret` -- OAuth secret *(required)*
* `:login_path` -- where user goes to login (default: "/login")
* `:return_to` -- where user goes after login (default: "/")


Helpers
-------

The `Twitter::Login::Helpers` module (for Sinatra, Rails) adds these methods to your app:

* `twitter_user` (Hashie::Mash) -- Info about authenticated user. Check this object to
  know whether there is a currently logged-in user. Access user data like `twitter_user.screen_name`
* `twitter_logout` -- Erases info about Twitter login from session, effectively logging-out the Twitter user
* `twitter_client` (Twitter::Base) -- An OAuth consumer client from ["twitter" gem][gem].
  With it you can query anything on behalf of authenticated user, e.g. `twitter_client.friends_timeline`

[register]: http://twitter.com/apps/new
[gem]: http://rdoc.info/projects/jnunemaker/twitter

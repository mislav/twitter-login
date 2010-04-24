Gem::Specification.new do |gem|
  gem.name    = 'twitter-login'
  gem.version = '0.2.2'
  gem.date    = Date.today
  
  gem.add_dependency 'twitter', '~> 0.9.5'
  gem.add_development_dependency 'rspec', '~> 1.2.9'
  gem.add_development_dependency 'fakeweb', '~> 1.2.8'
  
  gem.summary = "Rack middleware to provide login functionality through Twitter"
  gem.description = "Rack middleware for Sinatra, Rails, and other web frameworks that provides user login functionality through Twitter."
  
  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'http://github.com/mislav/twitter-login'
  
  gem.rubyforge_project = nil
  gem.has_rdoc = false
  
  gem.files = Dir['Rakefile', '{bin,lib,rails,test,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
end

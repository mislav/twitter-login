# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name    = 'twitter-login'
  gem.version = '0.4.3'
  gem.date    = Time.now.strftime('%Y-%m-%d')
  
  gem.add_dependency 'oauth', '~> 0.4.2'
  gem.add_dependency 'yajl-ruby', '>= 0.7.7'
  gem.add_dependency 'hashie', '>= 0.2.2'
  gem.add_development_dependency 'rspec', '>= 1.2.9'
  gem.add_development_dependency 'fakeweb', '~> 1.2.8'
  
  gem.summary = "Rack endpoint to provide login with Twitter functionality"
  # gem.description = "Nothing smart yet"
  
  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'http://github.com/mislav/twitter-login'
  
  gem.rubyforge_project = nil
  gem.has_rdoc = false
  
  gem.files = Dir['Rakefile', '{bin,lib,rails,test,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
end

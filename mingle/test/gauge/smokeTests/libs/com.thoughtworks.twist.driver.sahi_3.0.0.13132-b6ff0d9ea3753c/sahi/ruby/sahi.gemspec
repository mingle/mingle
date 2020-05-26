require 'rake'
spec = Gem::Specification.new do |s| 
  s.name = "sahi"
  s.version = "1.1.0"
  s.author = "Narayan Raman"
  s.email = "support@sahi.co.in"
  s.homepage = "http://sahi.co.in/w/ruby/"
  s.has_rdoc = true
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby driver for Sahi - automation tool for web applications"
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.extra_rdoc_files = ["README.txt"]
  s.add_dependency("guid", ">=0.1.1")  
  s.post_install_message = "Welcome to easy web automation using Sahi. You need to have Sahi proxy running before using this driver."
  s.description = "Ruby driver for Sahi (http://sahi.co.in/). Sahi is a web automation tool. \nSahi runs as a proxy, and the browser needs to be configured to use Sahi's proxy. \nThe browser can then be driven via the Sahi Ruby driver."
end
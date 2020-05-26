#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

# Disable Rake-environment-task framework detection by uncommenting/setting to false
# Warbler.framework_detection = false

# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  # Features: additional options controlling how the jar is built.
  # Currently the following features are supported:
  # - gemjar: package the gem repository in a jar file in WEB-INF/lib
  # - executable: embed a web server and make the war executable
  # - compiled: compile .rb files to .class files
  # config.features = %w(gemjar)

  # Application directories to be included in the webapp.
  # config.dirs = %w(app config db lib log script vendor tmp)
  if ENV['ENCRYPT_CODE'] == 'true'
    config.dirs = %w(tmp/encrypted/app app/views config db tmp/encrypted/lib vendor script)
  else
    config.dirs = %w(app config db lib vendor script)
  end

  # Additional files/directories to include, above those in config.dirs

  additional_files = ENV['TEST_DUAL_APP']? FileList["templates/**/*", "test/mocks/**/*", "test/test_helpers/*", "test/data/test_config/*"] : FileList["templates/**/*"]
  config.includes = additional_files


  # Additional files/directories to exclude
  # config.excludes = FileList["lib/tasks/*"]
  excluded_file_list = FileList[
                             "vendor/java",
                             "vendor/java/**/*",
                             "vendor/plugins/tagged_tests",
                             "vendor/plugins/inbrowsertest",
                             "vendor/plugins/tagged_tests/**/*",
                             "vendor/plugins/inbrowsertest/**/*",
                             "vendor/cache",
                             "vendor/cache/**/*",
                             "public/plugins",
                             "public/plugins/**/*",
                             "config/mingle.properties",
                             "config/database.yml.*",
                             'config/activemq.xml.*',
                             'config/eb_templates',
                             'config/eb_templates/*',
                             'config/keys',
                             'config/keys/*',
                             'config/mingle.properties*'
                             ]
  # if ENV["TEST_DUAL_APP"]
    excluded_file_list += %w(config/periodical_tasks.yml config/migrator_periodical_tasks.yml) if ENV["TEST_DUAL_APP"]
    excluded_file_list += %w(config/war/** config/log4j.* config/migrator_periodical_tasks.yml) if ENV['ENCRYPT_CODE']
  #   excluded_file_list -= %w(vendor/plugins/tagged_tests vendor/plugins/inbrowsertest
  #                            vendor/plugins/tagged_tests/**/* vendor/plugins/inbrowsertest/**/*)
  # end

  config.excludes = excluded_file_list
  # Additional Java .jar files to include.  Note that if .jar files are placed
  # in lib (and not otherwise excluded) then they need not be mentioned here.
  # JRuby and JRuby-Rack are pre-loaded in this list.  Be sure to include your
  # own versions if you directly set the value
  # config.java_libs += FileList["lib/java/*.jar"]
  config.java_libs += FileList[
                               "vendor/java/*.jar",
                               "vendor/java/elastic_search/*.jar"
                              ].exclude("vendor/java/jruby-*")

  # Loose Java classes and miscellaneous files to be included.
  # config.java_classes = FileList["target/classes/**.*"]
  config.java_classes = FileList["config/log4j.properties"] unless (ENV['ENCRYPT_CODE'] == 'true')

  # One or more pathmaps defining how the java classes should be copied into
  # the archive. The example pathmap below accompanies the java_classes
  # configuration above. See http://rake.rubyforge.org/classes/String.html#M000017
  # for details of how to specify a pathmap.
  # config.pathmaps.java_classes << "%{target/classes/,}p"
  config.pathmaps.java_classes << "%{config/,}p"

  # Bundler support is built-in. If Warbler finds a Gemfile in the
  # project directory, it will be used to collect the gems to bundle
  # in your application. If you wish to explicitly disable this
  # functionality, uncomment here.
  # config.bundler = false

  # An array of Bundler groups to avoid including in the war file.
  # Defaults to ["development", "test", "assets"].
  config.bundle_without = [] if ENV["TEST_DUAL_APP"]

  # Other gems to be included. If you don't use Bundler or a gemspec
  # file, you need to tell Warbler which gems your application needs
  # so that they can be packaged in the archive.
  # For Rails applications, the Rails gems are included by default
  # unless the vendor/rails directory is present.
  # config.gems += ["activerecord-jdbcmysql-adapter", "jruby-openssl"]
  # config.gems << "tzinfo"

  # Uncomment this if you don't want to package rails gem.
  # config.gems -= ["rails"]

  # The most recent versions of gems are used.
  # You can specify versions of gems by using a hash assignment:
  # config.gems["rails"] = "2.3.10"

  # You can also use regexps or Gem::Dependency objects for flexibility or
  # finer-grained control.
  # config.gems << /^merb-/
  # config.gems << Gem::Dependency.new("merb-core", "= 0.9.3")

  # Include gem dependencies not mentioned specifically. Default is
  # true, uncomment to turn off.
  # config.gem_dependencies = false

  # Array of regular expressions matching relative paths in gems to be
  # excluded from the war. Defaults to empty, but you can set it like
  # below, which excludes test files.
  # config.gem_excludes = [/^(test|spec)\//]

  # Pathmaps for controlling how application files are copied into the archive
  # config.pathmaps.application = ["WEB-INF/%p"]
  config.pathmaps.application = ['WEB-INF/%{^tmp/encrypted/}X%x']

  config.pathmaps.public_html = ['%{^public/,}X%x', '%{^help/build/,help/}X%x']
  # Name of the archive (without the extension). Defaults to the basename
  # of the project directory.
  if ENV['BUILD_DUAL_APP']
    # Name of the archive (without the extension). Defaults to the basename
    # of the project directory.
    config.jar_name = "ROOT"

    # Files to be included in the root of the webapp.  Note that files in public
    # will have the leading 'public/' part of the path stripped during staging.
    FileUtils.mkdir_p('./META-INF')
    FileUtils.cp('./config/war/context.xml', './META-INF/context.xml')
    config.public_html = FileList['public/**/*', 'META-INF/context.xml', 'help/build/**/*']
  else
    # Name of the archive (without the extension). Defaults to the basename
    # of the project directory.
    config.jar_name = "mingle"

    # Files to be included in the root of the webapp.  Note that files in public
    # will have the leading 'public/' part of the path stripped during staging.
    config.public_html = FileList["public/**/*", ".ebextensions/**/*", 'help/build/**/*']
  end

  # Name of the MANIFEST.MF template for the war file. Defaults to a simple
  # MANIFEST.MF that contains the version of Warbler used to create the war file.
  # config.manifest_file = "config/MANIFEST.MF"

  # When using the 'compiled' feature and specified, only these Ruby
  # files will be compiled. Default is to compile all \.rb files in
  # the application.
  # config.compiled_ruby_files = FileList['app/**/*.rb']

  # When set to true, Warbler will override the value of ENV['GEM_HOME'] even it
  # has already been set. When set to false it will use any existing value of
  # GEM_HOME if it is set.
  # config.override_gem_home = true

  # Allows for specifing custom executables
  # config.executable = ["rake", "bin/rake"]

  # Sets default (prefixed) parameters for the executables
  # config.executable_params = "do:something"

  # === War files only below here ===

  # Path to the pre-bundled gem directory inside the war file. Default
  # is 'WEB-INF/gems'. Specify path if gems are already bundled
  # before running Warbler. This also sets 'gem.path' inside web.xml.
  # config.gem_path = "WEB-INF/vendor/bundler_gems"

  # Files for WEB-INF directory (next to web.xml). This contains
  # web.xml by default. If there is an .erb-File it will be processed
  # with webxml-config. You may want to exclude this file via

  # config.webinf_files += FileList["jboss-web.xml"]

  # Pathmaps for controlling how public HTML files are copied into the .war
  # config.pathmaps.public_html = ["%{public/,}p"]

  # Embedded webserver to use with the 'executable' feature. Currently supported
  # webservers are:
  # * <tt>winstone</tt> (default) - Winstone 0.9.10 from sourceforge
  # * <tt>jenkins-ci.winstone</tt> - Improved Winstone from Jenkins CI
  # * <tt>jetty</tt> - Embedded Jetty from Eclipse
  # config.webserver = 'jetty'

  # Value of RAILS_ENV for the webapp -- default as shown below
  # config.webxml.rails.env = ENV['RAILS_ENV'] || 'production'

  # Application booter to use, one of :rack, :rails, or :merb (autodetected by default)
  # config.webxml.booter = :rails

  # When using the :rack booter, "Rackup" script to use.
  # - For 'rackup.path', the value points to the location of the rackup
  # script in the web archive file. You need to make sure this file
  # gets included in the war, possibly by adding it to config.includes
  # or config.webinf_files above.
  # - For 'rackup', the rackup script you provide as an inline string
  #   is simply embedded in web.xml.
  # The script is evaluated in a Rack::Builder to load the application.
  # Examples:
  # config.webxml.rackup.path = 'WEB-INF/hello.ru'
  # config.webxml.rackup = %{require './lib/demo'; run Rack::Adapter::Camping.new(Demo)}
  # config.webxml.rackup = require 'cgi' && CGI::escapeHTML(File.read("config.ru"))

  # DO NOT SET THESE (or else we cannot configure these per node via mingle.properties / system properties)
  # config.webxml.jruby.min.runtimes = 1
  # config.webxml.jruby.max.runtimes = 1

  # JNDI data source name
  # config.webxml.jndi = 'jdbc/rails'

  config.webxml.war.packaged = "true"
  config.webxml.rails.env = ENV["TEST_DUAL_APP"] ? 'test' : "production"
  config.webxml.rails.root = "/WEB-INF"
  config.webxml.public.root = "/"
end

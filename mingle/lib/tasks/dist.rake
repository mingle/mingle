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
require File.expand_path('../../mingle', __FILE__)
require File.expand_path('../../../config/initializers/document.rb', __FILE__)
require 'erb'

java_import "com.thoughtworks.mingle.util.ShellOut"

INSTALLER_VERSION = ENV["INSTALLER_VERSION"] || 'dev'
ENCRYPTED_BASE_DIR = 'tmp/encrypted'
ENCRYPTED_DIRS = %w{
  app/models
  app/helpers
  app/controllers
  app/jobs
  app/processors
  app/publishers
  lib
}

# this is just for dev and installers
def generate_webxml
  webxml = OpenStruct.new(:context_params => {
    :'rails.env' => 'production',
    :'rails.root' => ENV['HYBRID_APP'].present? ? '/WEB-INF' : '/',
    :'public.root' => ENV['HYBRID_APP'].present? ? '/' : '/public'
  })

  webxml.context_params.merge!({:'war.packaged' => true}) if ENV['HYBRID_APP'].present?

  config_folder = File.join(File.dirname(__FILE__), "../..", "config")
  template = File.read(File.join(config_folder, "web.xml.erb"))
  erb = ERB.new(template)
  File.open(File.join(config_folder, 'web.xml'), 'w') do |f|
    f.write(erb.result(binding))
  end
end

desc "build installers"
task :installers => %w(installers:validate_version_number installers:build_version_jar installers:encryptruby installers:doc installers:help assets web_xml installers:render_templates installers:build)

desc "Build installer with dual app setup"
task :dual_app_installers => %w(installers:validate_version_number installers:doc installers:render_templates installers:build_dual_app)

desc "generate config/web.xml from config/web.xml.erb"
task :web_xml do
  generate_webxml
end

desc "alias of web_xml"
task :webxml => [:web_xml]

namespace :installers do
  task :validate_version_number do
    if INSTALLER_VERSION != 'dev' && INSTALLER_VERSION !~ /\d+[\._]\d+/
      raise "The provided version should be in the form 'x_y' or 'x.y'"
    end
  end

  task :doc do
    ['INSTALL', 'UPGRADE'].each { |file| FileUtils.rm(file) if File.exists?(file) }
    File.open('INSTALL', 'w') do |f|
      f.write "Please see #{ONLINE_HELP_DOC_DOMAIN}/installing_mingle_on_unix.html\n"
    end
    File.open('UPGRADE', 'w') do |f|
      f.write "Please see #{ONLINE_HELP_DOC_DOMAIN}/upgrading_from_previous_versions.html\n"
    end
  end

  task :build do |_, args|
    Bundler.with_clean_env do
      system 'bundle --deployment --path=WEB-INF/gems --without=test development'
      system 'gem install development/build_gems/bundler-1.11.2.gem --install-dir WEB-INF/gems'
    end
    begin
      install_help_url = "#{ONLINE_HELP_DOC_DOMAIN}/installing_mingle.html"
      revision = Mingle::Revision::CURRENT
      puts "Building installer for version: #{INSTALLER_VERSION} (#{revision})"

      Bundler.with_clean_env do
        # need to unset CLASSPATH and JAVA_OPTS because rbenv-vars sets these
        # need to invoke ant with a clean environment
        system("CLASSPATH='' JAVA_OPTS='' development/build_java/ant/bin/ant  #{ENV["NOCRYPT"].nil? ? "-Dobfuscated=true" : ""} -Dversion=#{INSTALLER_VERSION} -Drevision=#{revision} -Dinstall_help_url=#{install_help_url} dist")
      end
    ensure
      rm_rf '.bundle'
      rm_rf 'WEB-INF'
    end
  end

  task :build_dual_app do
    begin
      install_help_url = "#{ONLINE_HELP_DOC_DOMAIN}/installing_mingle.html"
      revision = Mingle::Revision::CURRENT
      puts "Building installer for version: #{INSTALLER_VERSION} (#{revision})"

      Bundler.with_clean_env do
        # need to unset CLASSPATH and JAVA_OPTS because rbenv-vars sets these
        # need to invoke ant with a clean environment
        system("CLASSPATH='' JAVA_OPTS='' development/build_java/ant/bin/ant  #{ENV["NOCRYPT"].nil? ? "-Dobfuscated=true" : ""} -Dversion=#{INSTALLER_VERSION} -Drevision=#{revision} -Dinstall_help_url=#{install_help_url} dual_app_installer")
      end
    ensure
      rm_rf '.bundle'
      rm_rf 'WEB-INF'
    end
  end

  task :render_templates do
    puts '========================================'
    puts '                 Rendering Templates'
    puts '========================================'
    MINGLE_RUBY_VERSION = '1.9'
    Dir['tools/*.template', 'script/*.template'].each do |template_file|
      template = File.read(template_file)
      output_filename = template_file.gsub(/\.template$/, '')
      rendered = ERB.new(template)
      puts "Rendering #{template_file} to #{output_filename} ..."
      output_content = rendered.result(binding)
      File.open(output_filename, 'w') { |f| f.write(output_content) }
      puts 'Done'
    end
  end

  task :build_version_jar do
    system "CLASSPATH='' JAVA_OPTS='' development/build_java/ant/bin/ant -Dversion=#{INSTALLER_VERSION} -Drevision=#{Mingle::Revision::CURRENT} assemble-version-jar"
  end

  task :encryptruby do
    FileUtils.rm_rf ENCRYPTED_BASE_DIR
    # Redacted code snippets to encrypt the code
    puts "========================================"
    puts "                copying"
    puts "========================================"
    ENCRYPTED_DIRS.each do |dir|
      puts "#{dir} => #{ENCRYPTED_BASE_DIR}/#{dir}"
      FileUtils.mkdir_p("#{ENCRYPTED_BASE_DIR}/#{dir}")
      FileUtils.cp_r("#{dir}/.", "#{ENCRYPTED_BASE_DIR}/#{dir}")
    end
  end

  desc 'Build help doc'
  task :build_help do
    Bundler.with_clean_env { sh("rake --rakefile help/Rakefile") }
  end

  desc "Build and deploy help doc"
  task :help => :build_help do
    rm_rf('public/help')
    cp_r('help/build', 'public/help')
  end
end

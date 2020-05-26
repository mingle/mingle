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
require 'warble_helper'
require 'aws-sdk'

task 'minglewar' => ['war:build']

desc "generate and upload mingle.war file to s3 bucket for eb deployment, needs aws credentials in ENV"
task 'war_to_s3' => ['war:build', 'war:upload_to_s3']

def generate_installer_war
  WarbleHelper.copy_configs('context.xml')
  WarbleHelper.regenerate_webxml do
    puts "executing bundler.."
    Bundler.with_clean_env do
      Rake::Task['installers:encryptruby'].invoke
      # ENV['ENCRYPT_CODE'] = 'true'
      sh 'bundle exec warble war'
    end
  end
  WarbleHelper.restore_configs('context.xml')
end

def generate_war
  WarbleHelper.config do
    puts "executing bundler.."
    Bundler.with_clean_env do
      sh 'bundle exec warble war'
    end
  end
end

def installer_jars(installer_version, revision, install_help_url)
  sh("development/build_java/ant/bin/ant #{ENV["NOCRYPT"].nil? ? "-Dobfuscated=true" : ""} -Dversion=#{installer_version} -Drevision=#{revision} -Dinstall_help_url=#{install_help_url} jars dual-app-dispatcher-jar")
end

def non_installer_jars(installer_version, revision, install_help_url)
  sh("development/build_java/ant/bin/ant -Dversion=#{installer_version} -Drevision=#{revision} -Dinstall_help_url=#{install_help_url} jars dual-app-dispatcher-jar")
end

namespace :war do
  task :jars do |_ , args|
    installer_version = ENV["INSTALLER_VERSION"] || 'current'
    install_help_url = "#{ONLINE_HELP_DOC_DOMAIN}/installing_mingle.html"
    revision = Mingle::Revision::CURRENT
    puts "Building start-jar for version: #{installer_version} (#{revision})"
    args[:installer].nil? ?
        non_installer_jars(installer_version, revision, install_help_url) :
        installer_jars(installer_version, revision, install_help_url)
  end


  task :build, [:installer] => ['jars', 'installers:build_help'] do |_, args|
    if args[:installer] && args[:installer] == 'true'
      generate_installer_war
    else
      generate_war
    end
  end

  task :upload_to_s3, [:name] do |t, args|
    upload_artifact_to_s3(args[:name] || 'mingle.war')
  end

  private
  def upload_artifact_to_s3(file)
    s3_path = "wars/#{Digest::MD5.file(file).hexdigest}-#{File.basename(file)}"
    bucket_name = 'mingle-distribution'
    puts "start uploading to s3 at #{bucket_name}/#{s3_path}"

    AWS::S3.new.buckets[bucket_name].objects[s3_path].write(:file => file)
    puts 'uploading finished'

    dist = "dist/#{file}.yml"
    puts "generating source bundle #{dist}"
    FileUtils.mkdir_p(File.dirname(dist))
    File.open(dist, 'w') do |f|
      f << "s3_bucket: #{bucket_name}\n"
      f << "s3_key: #{s3_path}"
    end

  end

end

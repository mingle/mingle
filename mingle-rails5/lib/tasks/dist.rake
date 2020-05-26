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
INSTALLER_VERSION = ENV["INSTALLER_VERSION"] || 'dev'
ENCRYPTED_BASE_DIR = 'tmp/encrypted'
ENCRYPTED_DIRS = %w{
  app/models
  app/helpers
  app/controllers
  app/jobs
  app/lib
  app/views
  app/mailers
  app/channels
  lib
}

CRYPTO_UTILS_JAR = 'internal-crypto-utils.jar'
desc "alias of web_xml"
task :webxml => [:web_xml]

namespace :crypt do
  desc 'Ensures internal crypto utils jar is available'
  task :ensure_internal_crypto_utils_jar do
    unless File.exists?(File.join('lib', CRYPTO_UTILS_JAR))
      puts '[ENCRYPT] cannot find internal-crypto-utils.jar. Copying over from Mingle'
      jar_from_mingle = File.expand_path(File.join('..', 'mingle', 'installer', CRYPTO_UTILS_JAR))
      raise '[ENCRYPT] cannot find internal-crypto-utils.jar in lib or ../mingle/installer directory' unless File.exists?(jar_from_mingle)
      FileUtils.copy_file(jar_from_mingle, File.join('lib', CRYPTO_UTILS_JAR))
      system('gradle clean jar')
    end
  end

  desc 'Encrypt all the directories specified by ENCRYPTED_DIRS const'
  task :encrypt_ruby => :ensure_internal_crypto_utils_jar do
    # FileUtils.rm_rf ENCRYPTED_BASE_DIR
    #   puts "========================================"
    #   puts "               encrypting"
    #   puts "========================================"
    #   ENCRYPTED_DIRS.each do |dir|
    #     puts "#{dir} => #{ENCRYPTED_BASE_DIR}/#{dir}"
    #     system("java -cp vendor/java/commons-codec-1.6.jar:lib/internal-crypto-utils.jar com.thoughtworks.mingle.security.crypto.EncryptFiles #{dir} #{ENCRYPTED_BASE_DIR}/#{dir}")
    #   end
  end
end

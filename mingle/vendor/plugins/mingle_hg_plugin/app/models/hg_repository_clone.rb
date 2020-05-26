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

# Copyright 2010 ThoughtWorks, Inc. Licensed under the Apache License, Version 2.0.

# HgRepositoryClone manages when to pull from master to clone. Behavior pulled into
# decorator as it makes tests much faster and also keeps HgRepository more single-minded.
class HgRepositoryClone
    
  include FileUtils

  def initialize(repository, error_file_dir, project, retry_errored_connect = false)
    @repository = repository
    @error_file_dir = error_file_dir

    if File.exist?(error_file) && !retry_errored_connect
      raise StandardError.new(
        %{Mingle cannot connect to the Hg repository for project #{project.identifier}. 
        The details of the problem are in the file at #{error_file_dir}/error.txt}
      )
    end
  end

  def method_missing(method, *args)
    begin
      @repository.ensure_local_clone
      @repository.pull if (method.to_sym == :next_revisions) 
      delete_error_file 
    rescue StandardError => e
      write_error_file(e)
      raise e
    end

    @repository.send(method, *args)
  end

  private 

  def error_file
    "#{@error_file_dir}/error.txt"
  end

  def delete_error_file
    rm_f(error_file)
  end

  def write_error_file(e)    
    mkdir_p(File.dirname(error_file))
    File.open(error_file, 'w') do |file|
      file << "Message:\n#{e.message}\n\nTrace:\n"
      file << e.backtrace.join("\n")
    end
  end
    
end

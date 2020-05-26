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

module FileColumn # :nodoc:
  class BaseUploadedFile # :nodoc:
    def assign(file)
      # -------------- START PATCH --------------      
      if !file.respond_to?(:content_type) && file.is_a?(File)
      # -------------- END PATCH ----------------
        # this did not come in via a CGI request. However,
        # assigning files directly may be useful, so we
        # make just this file object similar enough to an uploaded
        # file that we can handle it. 
        file.extend FileColumn::FileCompat
      end
      
      # -------------- START PATCH --------------      
      wait_until_files_are_ready(file)
      # -------------- END PATCH ----------------
      
      if file.nil?
        delete
      else
        if file.size == 0
          # user did not submit a file, so we
          # can simply ignore this
          self
        else
          if file.is_a?(String)
            # if file is a non-empty string it is most probably
            # the filename and the user forgot to set the encoding
            # to multipart/form-data. Since we would raise an exception
            # because of the missing "original_filename" method anyways,
            # we raise a more meaningful exception rightaway.
            raise TypeError.new("Do not know how to handle a string with value '#{file}' that was passed to a file_column. Check if the form's encoding has been set to 'multipart/form-data'.")
          end
          upload(file)
        end
      end
    end
    
    private

    # when the server is running on windows, we sleep until file.size shows a non-zero value 
    # (otherwise files over 10k will not attach), see bug #3833
    def wait_until_files_are_ready(file)
      return unless file
      return if file.blank? || (!file.is_a?(Tempfile) && file.size == 0) || (file.is_a?(Tempfile) && File.zero?(file.path))
      sleep_interval = 0.01 # 10 milliseconds
      max_sleep_time = 30
      total_time_slept = 0

      while file.size == 0 && total_time_slept < max_sleep_time
        sleep(sleep_interval)
        total_time_slept += sleep_interval
      end
    end
    
  end
end

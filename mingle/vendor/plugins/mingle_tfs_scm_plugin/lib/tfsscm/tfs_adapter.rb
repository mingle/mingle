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

require 'java'

module Tfsscm
  class TfsAdapter
    def initialize(url, collection, project, domain, user, password)
      @url, @collection, @project, @domain, @user, @password =
        url, collection, project, domain, user, password
    end

    def changesets(from, limit)
      call_tfs(@url, @collection, @project, @domain, @user, @password, from, limit).map(&method(:convert_changeset))
    end

    private
    def convert_changeset(changeset)
      {
        :id => changeset['id'],
        :comment => changeset['comment'],
        :committer => changeset['committer'],
        :date => convert_date(changeset['date']),
        :changes => changeset['changes'].map(&method(:convert_change)),
      }
    end

    def convert_date(java_calendar)
      millis_since_epoch = java_calendar.getTimeInMillis
      Time.at(millis_since_epoch / 1000, millis_since_epoch % 1000)
    end

    def convert_change(change)
      {
        :path => convert_path(change['path']),
        :change_type => change['change-type'],
        :item_type => change['item-type'],
        :content_type => change['content-type'],
      }
    end

    def convert_path(path)
      path.gsub("$/#{@project}/", '')
    end

    def call_tfs(*args)
      class_loader.loadClass('com.thoughtworks.mingle.tfsscm.TFSAdapter').
        getMethod('call', *java_types(args)).
        invoke(nil, *args)
    end

    def class_loader
      @@class_loader ||= create_class_loader
    end

    def create_class_loader
      java.lang.System.setProperty('com.microsoft.tfs.jni.native.base-directory',
                                   absolute_path(%w[.. .. vendor tfs-sdk native]))

      jars = [%w[.. .. vendor tfs-sdk com.microsoft.tfs.sdk-11.0.0.jar],
              %w[.. .. mingle-tfs-adapter.jar]].
        map(&method(:url)).to_java(java.net.URL)
      java.net.URLClassLoader.new(jars, nil)
    end

    def java_types(xs)
      xs.map { |x| x.to_java.getClass }
    end

    def url(*file)
      java.io.File.new(absolute_path(file)).toURL
    end

    def absolute_path(relative_path)
      File.join(File.dirname(__FILE__), *relative_path)
    end
  end
end

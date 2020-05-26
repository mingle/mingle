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

require File.expand_path(File.join(File.dirname(__FILE__), 'hg_java_env'))

class HgSourceBrowser

  def initialize(java_hg_client, cache_path, mingle_revision_repository)
    @java_browser = com.thoughtworks.studios.mingle.hg.sourcebrowser::DefaultBrowser.new(java_hg_client, cache_path)
    @mingle_revision_repository = mingle_revision_repository
  end

  def tip_node(path, likely_tip_number, likely_tip_identifier)
    fix_node(@java_browser.tip_node(path, likely_tip_number.to_i, likely_tip_identifier))
  end

  def node(path, changeset_number, changeset_identifier)
    fix_node(@java_browser.node(path, changeset_number.to_i, changeset_identifier))  
  end

  def fix_node(node_to_fix)
    if node_to_fix.dir?
      @mingle_revision_repository.sew_in_most_recent_changeset_data_from_mingle(node_to_fix.children)
      node_to_fix.children.each do |child|
        def child.most_recent_commit_time
          java_date = super
          java_date.nil? ? nil : Time.at(java_date.time / 1000)
        end
      end
    end

    if !node_to_fix.dir?
      node_to_fix.instance_variable_set(:@__java_browser, @java_browser)
      def node_to_fix.file_contents(ruby_io)
        @__java_browser.file_contents_for(self, org.jruby.util.IOOutputStream.new(ruby_io))
      end
    end

    node_to_fix
  end

  def ensure_file_cache_synched_for(changeset_number, changeset_identifier = nil)
    @java_browser.ensure_file_cache_synched_for(changeset_number, changeset_identifier)
  end

  def raw_file_cache_content(revision_number)
    @java_browser.raw_file_cache_content(revision_number)
  end

  def cached?(revision_number)
    @java_browser.cached?(revision_number)
  end

  def clean_up_obsolete_cache_files
    @java_browser.clean_up_obsolete_cache_files
  end

  def binary?(path, changeset_identifier)
    @java_browser.binary?(path, changeset_identifier)
  end

end

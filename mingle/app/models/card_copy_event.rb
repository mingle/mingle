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

module CardCopyEvent

  def source_type
    'card'
  end

  def origin_description
     origin.nil? ? "Deleted card" : "Card ##{origin.number}"
  end

  def action_description
    "copied #{verb} #{associate_summary}"
  end

  def source_link
    origin.resource_link unless origin.nil?
  end

  def creation?
    false
  end

  def associate_summary
    "#{details[:associate_project_identifier]}/##{details[:associate_card_number]}"
  end

  def origin_url_options
    {
      :number => origin.number,
      :project_id => deliverable.identifier
    }
  end

  def associate_url_options
    {
      :number => details[:associate_card_number],
      :project_id => details[:associate_project_identifier]
    }
  end

  def verb
    self.class.name.demodulize.downcase
  end

  protected :associate_summary, :origin_url_options, :verb

  class Base < Event
    include CardCopyEvent
    include Messaging::MessageProvider

    class << self;
      def load_history_event(project, ids)
        ([]).tap do |result|
          ids.each_slice(ORACLE_BATCH_LIMIT) do |chunk_of_ids|
            result << Event.all(:conditions => ["deliverable_id = ? and id in (#{chunk_of_ids.join(',')})", project.id])
          end
        end
      end
    end

    def event_type
      :card_copy
    end

    def updated_at
      created_at
    end

    def do_generate_changes
      raise "must be implemented by subclasses"
    end

    def source
      raise "must be implemented by subclasses"
    end

    def destination
      raise "must be implemented by subclasses"
    end
  end

  class To < Base
    def do_generate_changes(options = {})
      changes.destroy_all
      changes.create_card_copy_to_change
    end

    def source
      origin_url_options unless origin.nil?
    end

    def destination
      associate_url_options
    end
  end

  class From < Base
    def do_generate_changes(options = {})
      changes.destroy_all
      changes.create_card_copy_from_change
    end

    def source
      associate_url_options
    end

    def destination
      origin_url_options unless origin.nil?
    end
  end
end

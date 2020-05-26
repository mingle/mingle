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

module Loaders
  class FirstProject
    
    def execute
      UnitTestDataLoader.delete_project('first_project')
      Project.create!(:name => 'Project One', 
                      :identifier => 'first_project', 
                      :corruption_checked => true,
                      :secret_key => 'this is secret', :time_zone => ActiveSupport::TimeZone['Brisbane'].name).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('first'))
        project.add_member(User.find_by_login('bob'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)


        UnitTestDataLoader.setup_property_definitions(
          :Status => ['fixed', 'new', 'open', 'closed','in progress'], 
          :Iteration => ['1', '2'], 
          :'Custom property' => ['old_value', 'some_new_value'],
          :old_type => ['bug', 'story', 'foo'],
          :'Some property' => ["first value"],
          :Priority => ['low', 'medium', 'high'],
          :'Property without values' => [],
          :Assigned => ['jen'],
          :Material => ['sand', 'wood', 'gold'],
          :Stage => ['25'],
          :Unused => ['value']
        )      

        UnitTestDataLoader.setup_user_definition('dev')
        UnitTestDataLoader.setup_text_property_definition('id')
        UnitTestDataLoader.setup_numeric_property_definition 'Release', ['1', '2']
        
        UnitTestDataLoader.setup_date_property_definition('start date')

        first_card = project.cards.create!(:number => 1, :name => 'first card', :description => 'this is the first card', :card_type => project.card_types.first)
        first_card.tag_with('first_tag').save!

        another_card = project.cards.create!(:number => 4, :name => 'another card', :description => 'another card is good', :card_type => project.card_types.first)
        another_card.tag_with('another_tag').save!

        first_page = project.pages.create!(:name => 'First Page', :content => 'Some content')
        second_page = project.pages.create!(:name => 'Second Page', :content => '')    

        project.reset_card_number_sequence
                
        FileUtils.mkdir_p("#{Rails.root}/public/attachments/randompath/1")
        FileUtils.touch("#{Rails.root}/public/attachments/randompath/1/IMG_1.jpg")
        FileUtils.mkdir_p("#{Rails.root}/public/attachments/bug_screenshot/path/2")
        FileUtils.touch("#{Rails.root}/public/attachments/bug_screenshot/path/2/card790.jpg")

        c = ActiveRecord::Base.connection
        if c.prefetch_primary_key?(Attachment)
          c.insert "INSERT INTO attachments (id, #{c.quote_column_name 'file'}, path, project_id) VALUES (#{c.next_sequence_value(Attachment.sequence_name)}, 'IMG_1.jpg', 'attachments/randompath', #{project.id})"
          c.insert "INSERT INTO attachments (id, #{c.quote_column_name 'file'}, path, project_id) VALUES (#{c.next_sequence_value(Attachment.sequence_name)}, 'card790.jpg', 'attachments/bug_screenshot/path', #{project.id})"
        else
          c.insert "INSERT INTO attachments (#{c.quote_column_name 'file'}, path, project_id) VALUES ('IMG_1.jpg', 'attachments/randompath', #{project.id})"
          c.insert "INSERT INTO attachments (#{c.quote_column_name 'file'}, path, project_id) VALUES ('card790.jpg', 'attachments/bug_screenshot/path', #{project.id})"
        end
        
        raise project.attachments if project.attachments.size != 2
        img_1 = project.attachments.detect { |attachment| attachment.file_name == 'IMG_1.jpg' }
        card790 = project.attachments.detect { |attachment| attachment.file_name == 'card790.jpg' }
        Attaching.create!(:attachment_id => img_1.id, :attachable_id => first_page.id, :attachable_type => 'Page')
        Attaching.create!(:attachment_id => img_1.id, :attachable_id => first_card.id, :attachable_type => 'Card')
        Attaching.create!(:attachment_id => card790.id, :attachable_id => first_card.id, :attachable_type => 'Card')
        Attaching.create!(:attachment_id => img_1.id, :attachable_id => first_card.versions.last.id, :attachable_type => 'Card::Version')
        Attaching.create!(:attachment_id => card790.id, :attachable_id => first_card.versions.last.id, :attachable_type => 'Card::Version')
        
        
        project.deactivate
      end
    end
    
  end
end

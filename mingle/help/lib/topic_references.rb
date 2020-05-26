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

require File.join(File.dirname(__FILE__), '..', '..', 'app', 'helpers', 'help_doc_helper')

module Topic
  class Referencable
    attr_reader :topic
    
    def initialize(topic)
      @topic = topic.downcase
    end
    
    def file_exists?
      return true unless topic
      return true if topic == 'index'
      File.exist?("#{TOPICS_DIR}/#{topic}.xml") || File.exist?("#{TOPICS_DIR}/fragments/#{topic}.xml")
    end
    
    def to_s
      topic
    end
  end
  
  class HelpTopicLink < Referencable
    def initialize(topic_link)
      super topic_link.split('#').first
    end
  end
  
  class MingleTargetLink < Referencable
    def initialize(help_link)
      help_link =~ /\/help\/(.*).html/
      super $1
    end
  end
  
  class HelpSourceFile < Referencable
    attr_reader :filename
    def initialize(full_filename)
      @filename = File.basename(full_filename)
      @filename =~ /(.*).xml/
      super $1
    end
  end
  
  class MingleSourceKey < Referencable
    attr_reader :title
    
    def initialize(title)
      @title = title
      @topic = nil
    end
    
    def to_s
      title
    end
  end
  
  class Reference
    attr_reader :source, :target
    
    def initialize(source, target)
      @source, @target = source, target
    end
  end

  class References
    attr_reader :source_filenames
    
    def initialize(source_filenames)
      @source_filenames = source_filenames
    end
    
    def all
      mingle_page_references + mingle_component_references + mingle_special_references + help_references
    end
    
    def unused_topics
      @unused_topics ||= (topics - referenced_topics)
    end
    
    private
    
    def topics
      source_filenames.map { |source_filename| HelpSourceFile.new(source_filename).topic } - ['under_construction', 'mingle_help_index']
    end
    
    def referenced_topics
      all.map { |reference| reference.target.topic }.uniq
    end
    
    def help_references
      @help_references ||= get_help_references
    end
    
    def get_help_references
      elements_and_attributes_to_match = { "//cref" => 'topic', "//topic" => 'file', "//entry" => 'reference', "//section" => 'file', "//subsection" => 'file', "//fragment" => 'file' }
      source_filenames.map do |source_filename|
        source = HelpSourceFile.new(source_filename)
        file = File.new(source_filename)
        references = []
        begin
          root = REXML::Document.new(file).root
          elements_and_attributes_to_match.each do |element_xpath, attribute_name|
            root.elements.each(element_xpath) do |element|
              topic = element.attributes[attribute_name]
              if topic
                references << Reference.new(source, HelpTopicLink.new(topic))
              end
            end
          end
        rescue
          puts "Could not process #{source_filename}."
        end
        references
      end.flatten
    end
    
    def mingle_page_references
      @mingle_page_references ||= mingle_references(MingleSourceKey.new('Mingle page help (help_doc_helper.rb)'), HelpDocHelper::PAGES)
    end
    
    def mingle_component_references
      @mingle_component_references ||= mingle_references(MingleSourceKey.new('Mingle component help (help_doc_helper.rb)'), HelpDocHelper::COMPONENTS)
    end
    
    def mingle_special_references
      @mingle_special_references ||= mingle_references(MingleSourceKey.new('Mingle special help (help_doc_helper.rb)'), HelpDocHelper::SPECIALS)
    end
    
    def mingle_references(source, help_doc_mapping)
      help_doc_mapping.map { |(key, value)| Reference.new(source, MingleTargetLink.new(value)) }.flatten
    end
  end
end

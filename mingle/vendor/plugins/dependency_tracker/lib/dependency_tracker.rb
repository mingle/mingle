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

require File.dirname(__FILE__) + '/view'


module Mingle
  class Project
    attr_reader :card_query_options
  end
end
module DependencyTracker
  class Macro
    def initialize(parameters, project, current_user)
      @parameters = parameters
      @project = project
      @program_macro = false
    end

    def execute
      View.new(@project,
               current_card,
               parameters.properties,
               projects,
               parameters.dependency_project,
               parameters.card_type,
               parameters.met,
               context_path,
               @program_macro,
               parameters.filter).display
    end

    def can_be_cached?
      false
    end

    protected

    def current_card
      content_provider = @project.card_query_options[:content_provider]
      content_provider.is_a?(::Card) ? content_provider : nil
    end

    private
    def context_path
      java.lang.System.getProperty "mingle.appContext"
    end

    def parameters
      Params.new(@parameters, @params_rule).validate
    end
  end

  class CardMacro < Macro
    def initialize(parameters, current_project, current_user)
      super
      @params_rule = [{:name => 'card-type', :default => [current_card_type].compact, :convert_to_array => true},
                      {:name => 'met', :mandatory => true},
                      {:name => 'properties', :default => [], :convert_to_array => true},
                      {:name => 'projects', :default => [current_project.identifier], :convert_to_array => true},
                      {:name => 'dependency-project', :default => current_project.identifier},
                      {:name => 'filter', :default=>nil}]
    end

    def projects
      parameters.projects.push(@project.identifier).uniq
    end

    def current_card_type
      current_card && current_card.card_type_name
    end
  end

  class ProjectMacro < Macro
    def initialize(parameters, current_project, current_user)
      super
      @params_rule = [{:name => 'card-type', :default => 'Story',
                        :convert_to_array => true},
                      {:name => 'met', :mandatory => true},
                      {:name => 'properties', :default => [], :convert_to_array => true},
                      {:name => 'projects', :default => [current_project.identifier], :convert_to_array => true},
                      {:name => 'dependency-project', :default => current_project.identifier},
                      {:name => 'filter', :default=>nil}]
    end

    def projects
      parameters.projects.push(@project.identifier).uniq
    end
  end

  class ProgramMacro < Macro
    def initialize(parameters, current_project, current_user)
      super
      @program_macro = true
      @params_rule = [{:name => 'card-type', :default => 'Story',
                        :convert_to_array => true},
                      {:name => 'met', :mandatory => true},
                      {:name => 'properties', :default => [], :convert_to_array => true},
                      {:name => 'projects', :mandatory => true, :convert_to_array => true},
                      {:name => 'dependency-project', :default => current_project.identifier},
                      {:name => 'filter', :default=>nil}]
    end

    def projects
      parameters.projects
    end
  end

  class Params
    def initialize(values, specs)
      @values = values
      @params = specs.map do |spec|
        Param.new(spec).
          value_from(values).
          installed_in(self.class)
      end
    end

    def validate
      @params.each &:validate
      return self
    end

    private
    class Param
      def initialize(spec) @spec=spec end
      def value_from(values)
        @raw_value = values[name]
        self
      end

      def installed_in(target)
        n, v = method_name(name), value
        target.class_eval { define_method(n) { v } }
        self
      end

      def validate()
        if @spec[:mandatory]
          @raw_value or raise "The parameter '#{name}' is missing."
        end
      end

      private
      def  method_name property_name
          property_name.gsub('-', '_')
      end

      def name()
        @spec[:name]
      end

      def value()
        value = @raw_value || @spec[:default]
        @spec[:convert_to_array] and value = Array(value)
        @spec[:converter] and value = @spec[:converter].call(value)
        value
      end
    end
  end
end

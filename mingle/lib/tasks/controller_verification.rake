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
def setup_verification_tracing
  ApplicationController.class_eval do
    class << self
      def verify_with_trace(options)
        parse_gets(options) if Array(options[:method]).include?(:get)
        parse_puts(options) if Array(options[:method]).include?(:put)
        parse_deletes(options) if Array(options[:method]).include?(:delete)
        parse_posts(options) if Array(options[:method]).include?(:post)
        verify_without_trace(options)
      end
      alias_method_chain :verify, :trace

      def parse_posts(options)
        parse_opts(options) { |actions| store_post_verifications(actions) }
      end

      def parse_gets(options)
        parse_opts(options) { |actions| store_get_verifications(actions) }
      end

      def parse_puts(options)
        parse_opts(options) { |actions| store_put_verifications(actions) }
      end

      def parse_deletes(options)
        parse_opts(options) { |actions| store_delete_verifications(actions) }
      end

      def parse_opts(options, &block)
        if !options[:only] && !options[:except]
          yield lambda { defined_actions }
        elsif options[:except]
          yield lambda { defined_actions - Array(options[:except]).collect(&:to_s) }
        else
          yield lambda { options[:only] }
        end
      end

      cattr_accessor :posts, :gets, :put_reqs, :deletes
      self.posts = {}
      self.gets = {}
      self.put_reqs = {}
      self.deletes = {}

      def unverifieds
        defined_actions.collect(&:to_s) - get_verifieds.collect(&:to_s) - post_verifieds.collect(&:to_s) - put_verifieds.collect(&:to_s) - delete_verifieds.collect(&:to_s)
      end

      def store_post_verifications(action_block)
        posts[self] ||= []
        posts[self] << action_block
      end

      def store_get_verifications(action_block)
        gets[self] ||= []
        gets[self] << action_block
      end

      def store_put_verifications(action_block)
        put_reqs[self] ||= []
        put_reqs[self] << action_block
      end

      def store_delete_verifications(action_block)
        deletes[self] ||= []
        deletes[self] << action_block
      end

      def get_verifieds
        verified gets[self]
      end

      def post_verifieds
        verified posts[self]
      end
      
      def put_verifieds
        verified put_reqs[self]
      end
      
      def delete_verifieds
        verified deletes[self]
      end
      
      def verified(action_blocks)
        (action_blocks || []).collect(&:call).flatten
      end

      def defined_actions
        (public_instance_methods - ApplicationController.public_instance_methods - SkipAuthentication.instance_methods).collect(&:to_s)
      end
    end
  end
end

task :check_unguarded_actions => [:environment] do
  setup_verification_tracing
  exemptions = {
    'HistoryController' => ['index'], 
    'ProfileController' => ['login'], 
    'ProjectsController' => ['health_check'], 
    'CardsController' => ['current_tree', 'list', 'new', 'edit', 'history', 'select_tree', 'bulk_set_properties_panel', 'show_tree_cards_quick_add', 'show_tree_cards_quick_add_on_card_show_page', 'show_tree_cards_quick_add_to_root'],
    'CardsImportController' => ['display_preview'], 
    'InstallController' => ["index", "migrate", "configure_smtp", "skip_configure_smtp", "connect", "eula", "signup", "register_license", "import_templates"]}
  
  unspecified_actions = {}
  Dir['app/controllers/*_controller.rb'].each do |f| 
    next if f =~ /application_controller/
    require f
    controller_class = f.gsub('app/controllers/', '').gsub('.rb', '').camelize.constantize
    next if controller_class.is_a? Module
    next if controller_class.superclass != ApplicationController
    unverified_actions = (controller_class.unverifieds - Array(exemptions[controller_class.name]))
    unspecified_actions[controller_class] = unverified_actions unless unverified_actions.empty?
  end

  unless unspecified_actions.empty?
    puts "The following controller have some unguarded actions"
    unspecified_actions.keys.sort_by(&:name).each do |c|
      puts "#{c.name} => #{unspecified_actions[c].inspect}"
      puts
    end
    raise "Fail" unless unspecified_actions.empty?
  end
end

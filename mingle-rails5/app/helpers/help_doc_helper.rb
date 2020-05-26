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

module HelpDocHelper

  PAGES = {
            'About Page'                        => '/about_page.html',
            'Aggregate Properties Page'         => '/aggregate_properties.html',
            'All Projects Page'                 => '/all_projects_page.html',
            'Card grid page'                    => '/card_grid_page.html',
            'Card hierarchy page'               => '/hierarchy_view.html',
            'Card tree page'                    => '/tree_view.html',
            'Card list page'                    => '/card_list_page.html',
            'Card Keywords Page'                => '/card_keywords_page.html',
            'Card Properties Page'              => '/card_properties_page.html',
            'Card Property Values Page'         => '/card_property_values_page.html',
            'Card Transitions Page'             => '/card_transitions_page.html',
            'Card Trees Page'                   => '/card_trees.html',
            'Card Types Page'                   => '/card_types.html',
            'Card View Page'                    => '/card_view_page.html',
            'charts and reporting'              => '/creating_charts_and_tables.html',
            'Configure Email Settings Page'     => '/configure_email_settings_page.html',
            'Configure Project Repository Page' => '/setup_source_repository_integration.html',
            'Connect Mingle to your database'   => '/mingle_installation_step1.html',
            'Set up the database'               => '/mingle_installation_step2.html',
            'URL settings'                      => '/mingle_installation_step3.html',
            'SMTP settings'                     => '/mingle_installation_step4.html',
            'Review the License'                => '/mingle_installation_step5.html',
            'Set up the first user account'     => '/mingle_installation_step6.html',
            'Import project templates'          => '/mingle_installation_step7.html',
            'Register Mingle'                   => '/mingle_installation_step8.html',
            'Mingle Licenses'                   => '/mingle_licenses.html',
            'Connect Database'                  => '/configuring_a_database_for_use_with_mingle.html',
            'Copy Card'                         => '/copying_a_card.html',
            'Creating Mingle Projects'          => '/creating_mingle_projects.html',
            'Create project variable'           => '/creating_project_variables.html',
            'Create project'                    => '/creating_mingle_projects.html',
            'Create property'                   => '/creating_card_properties.html',
            'Create transition'                 => '/creating_card_transitions.html',
            'Create tree configuration'         => '/creating_a_new_card_tree.html',
            'Create user'                       => '/creating_user_profiles.html',
            'Edit card'                         => '/updating_cards.html',
            'Edit card defaults'                => '/card_defaults.html',
            'Edit Profile Page'                 => '/edit_profile_page.html',
            'Manage Profile Page'               => '/managing_your_user_profile.html',
            'Edit project variable'             => '/modifying_or_deleting_project_variables.html',
            'Edit property'                     => '/modifying_or_deleting_card_properties.html',
            'Edit transition'                   => '/modifying_or_deleting_card_transitions.html',
            'Edit user profile'                 => '/managing_your_user_profile.html',
            'Excel import'                      => '/import_export_component.html',
            'Explore Mingle Page'               => '/explore_mingle_page.html',
            'Favorites Page'                    => '/favorites_and_tabs_page.html',
            'Formula Properties Page'           => '/formula_properties.html',
            'History Tab'                       => '/history_tab.html',
            'Main Page'                         => '/index.html',
            'Manage Templates Page'             => '/standard_mingle_templates.html',
            'Murmurs'                           => '/murmurs.html',
            'Overview Tab'                      => '/project_overview_tab.html',
            'Project Numeric Precision'         => '/project_numeric_precision.html',
            'Project Settings Page'             => '/project_settings_page.html',
            'Project Variables Page'            => '/project_variables.html',
            'Revision'                          => '/revisions_page.html',
            'Advanced Search Page'              => '/mingle_search.html#advanced_search_options',
            'Show page'                         => '/working_with_pages.html',
            'Sign In Page'                      => '/signing_in_and_out_of_mingle.html',
            'Sign Out Page'                     => '/signing_in_and_out_of_mingle.html',
            'Source Tab'                        => '/source_tab.html',
            'Tags Page'                         => '/tags_page.html',
            'Team Page'                         => '/project_team_page.html',
            'Transitions Workflow Page'         => '/transition_workflow_page.html',
            'Too Many Macros'                   => '/too_many_macros.html',
            'Users Page'                        => '/manage_users_page.html',
            'Welcome to Mingle Page'            => '/completing_the_mingle_configuration_wizard.html',
            'Page'                              => '/page_card_layout.html',
            'Pages Page'                        => '/pages_page.html',

            'Configure SSL'                     => '/configure_ssl.html',
            'Groups Page'                       => '/user_groups_page.html',
            'Group Page'                        => '/user_group_page.html',
            'Add Group Members Page'            => '/user_group_page.html#add_to_group',

            # Planner Help
            'Program Import'              => '/export_import_program.html',
            'Program Export'              => '/export_import_program.html'
          }

  COMPONENTS = {
    'Add current view to my favorites'   => '/my_favorites_component.html',
    'Add current view to team favorites' => '/favorites_component.html',
    'Card Murmurs and History'              => '/card_murmurs_and_history_components.html',
    'Team favorites'                     => '/favorites_component.html',
    'My favorites'                       => '/my_favorites_component.html',
    'Filter cards by...'                 => '/filter_list_by_component.html',
    'Filter history'                     => '/filter_history_component.html',
    'Filter list by MQL'                 => '/filter_list_by_mql.html',
    'Formatting help'                    => '/formatting_help_component.html',
    'History'                            => '/page_history_component.html',
    'Import / Export'                    => '/import_export_component.html',
    'Subscription'                       => '/subscription_component.html',
    'Auto Sync'                          => '/define_your_plan.html#autosync'
  }

  SPECIALS = {
    'MQL'                  => '/macro_and_mql_guide.html',
    'Macro Reference'      => '/macro_reference.html',
    'project-variable'     => '/macro_reference.html#project_variable',
    'average'              => '/macro_reference.html#average_query',
    'value'                => '/macro_reference.html#value_query',
    'table-query'          => '/macro_reference.html#table_query',
    'table-view'           => '/macro_reference.html#table_view',
    'pivot-table'          => '/macro_reference.html#pivot_table',
    'stack-bar-chart'      => '/macro_reference.html#stack_bar',
    'data-series-chart'    => '/macro_reference.html#data_series',
    'daily-history-chart'  => '/macro_reference.html#daily_history_chart',
    'ratio-bar-chart'      => '/macro_reference.html#ratio_bar_chart',
    'pie-chart'            => '/macro_reference.html#pie_chart',
    'Corruption Propeties' => '/corrupt_properties.html',
    'System Requirement'   => '/system_requirements.html'
  }

  PAGE_HELP_CSS      = 'page-help'
  COMPONENT_HELP_CSS = 'component-help'
  SPECIALS_HELP_CSS  = 'specials-help'
  TITLE              = 'Click to open help document'

  def render_help_link(name, opt = {})
    name.gsub!(/\s+/, ' ') unless name.blank?
    url, css, content = if PAGES.has_key?(name)
      [PAGES[name], PAGE_HELP_CSS, 'Help']
    elsif COMPONENTS.has_key?(name)
      [COMPONENTS[name], COMPONENT_HELP_CSS, image_tag('shared/icons/icon_help_16.png', :alt => TITLE)]
    elsif SPECIALS.has_key?(name)
      [SPECIALS[name], SPECIALS_HELP_CSS, image_tag('icon-page-help.gif', :alt => TITLE)]
    end

    %Q[<a href="#{link_to_help(url)}" target="blank" title="#{TITLE}" style="#{opt[:style]}" class="#{opt[:class] || css}">#{opt[:content] || content}</a>].html_safe
  end

  def simple_help_link(name)
    if name
      "&nbsp;<a href='#{link_to_help(name)}' target='blank'>Help</a>"
    end
  end

  def link_to_help(page_uri)
    "#{HELP_DOC_DOMAIN}#{PAGES[page_uri] || COMPONENTS[page_uri] || SPECIALS[page_uri] || page_uri}"
  end

  def title_with_help_link(title, link_name, opt={})
    %{
      <p>
        #{render_help_link(link_name, opt)}
        <h1>#{title}</h1>
        #{clear_float}
      </p>
    }
  end

  def contextual_help_exists?(params)
    path = File.join(File.expand_path(File.dirname(__FILE__) + '/../../public'), 'contextual_help', "#{contextual_help_file_name(params)}.html.template")
    File.exists?(path)
  end

  def contextual_help_location(params)
    "#{CONTEXT_PATH}/contextual_help/#{contextual_help_file_name(params)}.html"
  end

  def contextual_help_link(position, html_options={})
    link_to_function('Show help', 'ContextualHelpController.toggle()', {:id => 'contextual_help_link', :class => 'page-help-at-action-bar'}.merge(html_options)) if position == 'top'
  end

  def contextual_help_file_name(params)
    params.merge!(@view.to_params) if params.include?(:view)

    rules = [
      [{:maximized => 'true'}, 'empty'],
      [{:action => 'list', :controller => 'cards', :style => 'grid'}, 'cards_grid'],
      [{:action => 'list', :controller => 'cards', :style => 'list'}, 'cards_list'],
      [{:action => 'list', :controller => 'cards', :style => 'hierarchy'}, 'cards_hierarchy'],
      [{:action => 'list', :controller => 'cards', :style => 'tree'}, 'cards_tree']
    ]

    matched = rules.find do |rule, filename|
      params.contains?(rule)
    end

    file = if matched
      matched.last
    else
      "#{params[:controller]}_#{params[:action]}"
    end

    if params.include?(:tree_name)
      file << '_with_tree'
    end
    file
  end

end

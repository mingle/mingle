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

class CardListView < ActiveRecord::Base
  include PaginationSupport
  DEFAULT_ORDER = 'asc'
  ORDERS = [DEFAULT_ORDER, 'desc']
  POTENTIAL_STATUS_PROPERTIES = /status|stage|state/i

  belongs_to :project
  before_save :clean_up_params, :build_canonical_strings, :serialize_params
  after_save :save_favorite
  validates_presence_of :name
  validate_on_update :detect_maximized_tab
  has_one :favorite, :as => :favorited
  has_many :user_filter_usages, :as => :filterable, :dependent => :destroy
  before_destroy :destroy_favorite

  use_database_limits_for_all_attributes
  attr_accessor :tagged_with, :columns, :style, :page, :maximized, :sort, :order, :filters, :groups, :expands, :tree_name, :workspace, :fetch_descriptions, :wip_limits

  class << self
    def find_or_construct(belong_to_project, params = {})
      belong_to_project.find_or_construct_team_card_list_view(params)
    end

    def construct_from_params(belong_to_project, params, defensively=true)
      result = new
      result.project = belong_to_project
      result.name = params[:name]
      result.build_favorite(:favorited_type => name, :tab_view => false, :user_id => params[:user_id], :project_id => belong_to_project.id)
      result.load_from_params(params, defensively)
      result
    end

    def create_or_update(params = {}, metrics_helper=nil)
      view_name = params[:view][:name].strip
      project_id = current_scoped_methods[:create]['project_id']
      with_scope(:create => {'project_id' => project_id}, :find => {:conditions => {'project_id' => project_id}}) do
        view = first :include => :favorite, :conditions => uniqueness_conditions(params, view_name)
        view ||= new(:name => view_name, :project_id => project_id)
        view.name = view_name
        view.load_from_params(params, true)
        add_wip_monitoring_event(view, params, metrics_helper, project_id) if !metrics_helper.nil?
        view.save!
        view.create_favorite(:favorited_type => name, :favorited_id => view.id, :tab_view => false, :user_id => params[:user_id], :project_id => project_id) unless view.favorite
        view
      end
    end

    def add_wip_monitoring_event(view, params, metrics_helper, project_id)
      wip_changed = (params && view.params && view.params[:wip_limits] != params[:wip_limits])
      metrics_helper.add_monitoring_event('wip_limits_changed', {'project_id' => project_id}) if wip_changed
    end

    # construct a new card list view object, grantee to clear all caches
    def reload(view)
      CardListView.find_or_construct(view.project, view.to_params)
    end

    private
    def uniqueness_conditions(params, view_name)
      if params[:user_id]
        ['favorites.user_id = ? AND LOWER(card_list_views.name) = LOWER(?)', params[:user_id], view_name]
      else
        ['favorites.user_id IS NULL AND LOWER(card_list_views.name) = LOWER(?)', view_name]
      end
    end
  end

  def after_find
    self.params = YAML.load(self.params)
    load_from_params(self.params, false)
  end
  ## set defensively to false in the case when you're sure the parameters are completely valid and need to save computation time
  def load_from_params(parameters, defensively=true)
    translate_old_aggregate_params(parameters)
    @tagged_with = Tag.parse(parameters[:tagged_with])
    @page = parameters[:page] || "1"
    @cards_per_page = parameters[:page_size]
    @tree_name = parameters[:tree_name]

    if tree_id = parameters.delete(:tree_id)
      @tree_name = project.tree_configurations.find(tree_id.to_i).name
    end

    @workspace = CardView::Workspace.new(self)

    if defensively && @workspace.invalid?
      @tree_name = nil
    end
    @filters = workspace.parse_filter_params(parameters)
    @sort = parse_sort(parameters[:sort])
    @order = parse_order(parameters[:order])
    @maximized = parameters[:maximized]
    @columns = CardView::ListColumns.new(parameters[:columns])
    @hide_wip_limits = parameters[:hide_wip_limits]
    @wip_limits = CardView::WipSupport.sanitize_wip_limits(parameters[:wip_limits])

    if defensively
      parameters.delete(:group_by) unless valid_group_by_properties?(parameters[:group_by])
      parameters.delete(:color_by) unless valid_color_by_property?(parameters[:color_by])
      parameters.delete(:grid_sort_by) unless valid_grid_sort_by_property?(parameters[:grid_sort_by])
      [:aggregate_type, :aggregate_property].each { |param| parameters.delete(param) } unless valid_aggregate_settings?(parameters)
    end

    @style = CardView::Style.from_str(parameters[:style].to_s)
    @groups = CardView::GroupLanes.create(self, parameters)
    @all_cards_selected = parameters[:all_cards_selected] if parameters[:all_cards_selected] == 'true'
    @selected_cards = parameters[:selected_cards] if parameters[:selected_cards]
    @tab_name = parameters[:tab] if parameters[:tab]
    @expands = (parameters[:expands] || '').split(',').map(&:to_i)

    # don't serialize this setting in to_params, should never be saved.
    @fetch_descriptions = parameters[:format] == "xml" || parameters[:api_version].present? # api requests need to serialize all columns

    remove_invalid_columns! if defensively
  end

  def group_lanes
    @groups
  end

  def ready_for_cta?
    group_lanes.lane_property_definition &&
      group_lanes.lane_property_definition.name =~ POTENTIAL_STATUS_PROPERTIES &&
      !invalid?
  end

  def has_completed_cards?
    visible_property_value_lanes.any? && visible_property_value_lanes.last.cards.any?
  end

  def visible_property_value_lanes
    (group_lanes.visibles(:lane) - [group_lanes.not_set_lane].compact)
  end

  def style_description
    "".tap do |description|
      description << "maximized " if maximized
      description << style.to_s
    end
  end

  def reload_lane_order
    group_lanes.reset_lanes
  end

  def to_js_params
    ret = to_params
    ret. delete(:action)
    ret[:page] = @page unless @page == '1'
    ret
  end

  def to_transformed_filters
    conditions = filter_column_query.conditions
    mql_clause = nil
    if conditions
      begin
        mql_clause = CardQuery::MqlGeneration.new(conditions).execute
        ::LiveFilters.parse("where #{mql_clause}")
      rescue => e
        Alarms.notify(e, :project => project.identifier, :filters => conditions, :generated_mql => mql_clause, :params => to_params)
      end
    end
  end

  def sort_by_property_definition
    unless grid_sort_by.nil?
      @sort_by_property_definition ||= filters.properties_for_grid_sort_by.find {|property| property.name.downcase == grid_sort_by.downcase}
    end
    @sort_by_property_definition
  end

  def to_params
    {:action => action}.tap do |params|
      if CardView::Style.support_pagination?(@style)
        current_page = @style.current_page(self)
        params[:page] = current_page if current_page.to_i > 1
      end
      params[:tagged_with] = @tagged_with.join(',') unless @tagged_with.blank?
      params.merge!(workspace.create_filter_params(@filters.to_params)) if @filters && !@filters.to_params.empty?
      params[:style] = @style.to_s
      params[:columns] = @columns.to_s unless @columns.blank?
      params[:sort] = @sort if @sort
      params.merge!(group_lanes.to_params) if group_lanes
      params[:order] = @order if @order
      params[:maximized] = @maximized if @maximized
      params[:all_cards_selected] = @all_cards_selected if @all_cards_selected
      params[:tree_name] = @tree_name if @tree_name
      params[:wip_limits] = @wip_limits if @wip_limits
      params[:hide_wip_limits] = @hide_wip_limits unless @hide_wip_limits.nil? || @hide_wip_limits == false
      params[:expands] = @expands.join(',') if expands.any?
      params[:tab] = if new_record?
        (@tab_name || DisplayTabs::AllTab::NAME)
      elsif !tab_view?
        DisplayTabs::AllTab::NAME
      else
        (@tab_name || name)
      end.dup
    end
  end
  memoize :to_params, :return_clone => true

  def to_tab_params
    ret = to_params
    ret.delete(:rank_is_on)
    ret
  end

  def link_params
    to_params.merge(:controller => 'cards')
  end

  def card_types
    @filters.no_card_type_filters? ? project.card_types : @filters.card_type_names.map { |name| project.find_card_type(name) }
  end

  def all_cards_selected?
    @all_cards_selected == 'true'
  end

  def remove_invalid_columns!
    @sort = nil unless valid_column?(@sort)
    @order = nil if @sort.nil?
    @columns.delete_if{|c| !valid_column?(c)} unless @columns.nil?
  end

  def filter_parameters

    filters.filter_parameters + [:all_cards_selected, :tagged_with, :lanes]
  end
  def valid_group_by_properties?(property_names)
    property_names.nil? || CardView::GroupByParam.new(property_names).included_in?(filters.properties_for_group_by)
  end

  def valid_color_by_property?(property_name)
    property_name.nil? || filters.properties_for_colour_by.any?{|property| property.name.downcase == property_name.downcase}
  end

  def valid_grid_sort_by_property?(property_name)
    property_name.nil? || filters.properties_for_grid_sort_by.any?{|property| property.name.downcase == property_name.downcase}
  end

  def valid_aggregate_settings?(params)
    Aggregate.row_valid?(project, params) && Aggregate.column_valid?(project, params)
  end

  def parse_sort(sort)
    return nil if sort.blank?
    sort
  end

  def parse_order(order)
    return nil unless @sort
    return DEFAULT_ORDER if order.blank?
    ORDERS.detect { |o| o == order.downcase }
  end

  def reset_paging
    clear_cached_results_for :paginator
    clear_cached_results_for :to_params
  end

  def card_count
    return 0 if invalid?
    @style.displaying_card_count(self)
  end

  def filter_tags
    tags = tagged_with.inject([]) do |result, tag_name|
      next(result) if tag_name.empty?
      result << tag_name
      result
    end
    tags.uniq
  end

  def flip_sort_params(sort_column)
    return flip_order_params if @sort && @sort.downcase == sort_column.to_s.downcase
    params = to_params
    params[:sort] = sort_column
    params[:order] = DEFAULT_ORDER
    params
  end

  def flip_order_params
    params = to_params
    params[:order] = @order && @order.downcase == 'asc' ? 'desc' : 'asc'
    params
  end

  def card_query_for_relationship_filter(card_type, property_definition)
    filters.card_query_for_relationship_filter(card_type, property_definition)
  end

  def clear_sort
    params = to_params
    params[:sort] = nil
    params[:order] = nil
    CardListView.construct_from_params(project, params)
  end

  def add_filter_tag(tag)
    params = to_params
    params[:tagged_with] ||= ""
    params[:tagged_with] = (params[:tagged_with].split(',') + [tag]).join(',')
    CardListView.construct_from_params(project, params)
  end

  def add_filter_property(property, operator, value)
    params = to_params
    params[:filters] ||= []
    params[:filters] << Filters::Filter::encode(property, value, operator)
    CardListView.construct_from_params(project, params)
  end

  def reset_filter_properties
    params = to_params
    params.delete(:filters)
    CardListView.construct_from_params(project, params)
  end

  def reset_all_filters
    params = to_params
    params.delete(:tagged_with)
    CardListView.construct_from_params(project, params)
  end

  def reset_tab_to(name_of_a_tab_view)
    project.default_view_for_tab(name_of_a_tab_view)
  end

  def reset_only_filters_to(name_of_a_tab_view)
    default_tab_view = project.default_view_for_tab(name_of_a_tab_view)
    non_filter_params = self.to_params.except(*self.filter_parameters)
    filter_params = (default_tab_view && default_tab_view.tree_name == self.tree_name) ? default_tab_view.to_params.slice(*default_tab_view.filter_parameters) : {}
    return CardListView.construct_from_params(project, non_filter_params.merge(filter_params))
  end

  # pivot table performance boost by adding columns and clearing sort all at once: only have to reconstruct view one time
  def add_columns_and_clear_sort(columns)
    params = to_params
    columns.each { |col| @columns = @columns.add_column(col) }
    params[:columns] = @columns
    params[:page] = @page
    params[:sort] = nil
    params[:order] = nil
    CardListView.construct_from_params(project, params, false)  # turn off validation for speed purposes
  end

  def add_column(column)
    params = to_params
    params[:columns] = @columns.add_column(column)
    params[:page] = @page
    CardListView.construct_from_params(project, params)
  end

  def remove_column(column)
    params = to_params
    if @sort && @sort.downcase == column.downcase
      params[:page] = params[:order] = params[:sort] = nil
    else
      params[:page] = @page
    end
    params[:columns] = @columns.remove_column(column)
    CardListView.construct_from_params(project, params)
  end

  def support_columns?
    CardView::Style::support_columns?(style)
  end

  def has_column?(column)
    @columns.has_column?(column)
  end

  def invalid?
    filters.invalid? || workspace.invalid?
  end

  def too_many_results?
    style.too_many_results?(self)
  end

  def cards
    return [] if invalid?
    @style.displaying_cards(self)
  end
  memoize :cards

  def include_number?(card_number)
    all_card_numbers.include?(card_number)
  end

  def all_cards_size
    card_numbers.size
  end

  def card_numbers
    return [] if invalid?
    @style.find_card_numbers(self) rescue []
  end
  memoize :card_numbers

  def all_card_numbers
    return [] if invalid?
    workspace.all_cards_query.find_card_numbers
  end
  memoize :all_card_numbers

  def all_cards
    return [] if invalid?
    workspace.tree_workspace? ? all_cards_tree.nodes_without_root : as_card_query.find_cards
  end
  memoize :all_cards

  def column_property_definitions
    columns.collect { |column| project.find_property_definition_including_card_type_def(column) }.compact
  end

  def describe_current_filters
    "Current cards: #{@filters && !@filters.description_without_header.blank? ? @filters.description_without_header : 'All'}"
  end

  def column_header_html_class(column)
    if @sort && @sort.downcase == column.to_s.downcase
      @order.downcase
    end
  end

  def empty?
    to_params.empty?
  end

  def page_title
    "#{project.name} #{@tab_name == DisplayTabs::AllTab::NAME ? 'Cards' : (name || sanitize(@tab_name))}"
  end

  def params_for_current_page
    params = to_params
    params.merge!(:page => page) if CardView::Style.support_pagination?(style)
    @style.clear_not_applicable_params!(params)
    params
  end

  def team?
    !personal?
  end

  def personal?
    favorite.personal?
  end

  def tabbable?
    !maximized
  end

  def pagination_options
    {:limit => paginator.items_per_page, :offset => paginator.current_page_offset}
  end

  def paginated?
    CardView::Style.support_pagination?(style)
  end

  def describe_current_page
    @style.describe_current_page(self)
  end

  def to_current_page_params
    to_params.merge :page => page
  end

  def as_card_query
    @workspace.all_cards_query
  end

  def dirty_compared_to?(another)
    self.canonical_string != another.canonical_string
  end

  def downcase_values(hash)
    hash.each {|k, v| v.respond_to?(:downcase!) ? v.downcase! : v.each(&:downcase!)}.symbolize_keys
  end

  def ==(another)
    return false unless another.respond_to?(:to_params)
    equal_param_hashes(self.to_params, another.to_params)
  end

  def filter_count
    count = 0
    count += tagged_with.length unless tagged_with.nil?
    count += filters.size if filters
    count
  end

  def rename_card_type(old_name, new_name)
    clear_cached_results_for :to_params
    @filters.rename_card_type(old_name, new_name) if @filters
    rename_wip_params(old_name, new_name)
  end

  def rename_property(old_name, new_name)
    clear_cached_results_for :to_params
    @filters.rename_property(old_name, new_name) if @filters
    @columns = @columns.rename_column(old_name, new_name) if @columns
    @sort = new_name unless @sort.nil? || @sort.to_s.downcase != old_name.to_s.downcase
    group_lanes.rename_property(old_name, new_name)
  end

  def rename_property_value(property_name, old_value, new_value)
    clear_cached_results_for :to_params
    filter_updated = filters.rename_property_value(property_name, old_value, new_value)
    filter_updated = group_lanes.rename_property_value(property_name, old_value, new_value) || filter_updated
    rename_wip_params(old_value, new_value)
    filter_updated
  end

  def rename_project_variable(old_name, new_name)
    @filters.rename_project_variable(old_name, new_name)
    save!
  end

  def rename_tree(old_name, new_name)
    if @filters
      clear_cached_results_for :to_params
      @filters.rename_tree(old_name, new_name)
    end
  end

  def change_tree_config_name(old_value, new_value)
    return unless old_value.ignore_case_equal?(@tree_name)
    clear_cached_results_for :to_params
    @tree_name = new_value
    save!
  end

  def update_date_format(old_format, new_format)
    clear_cached_results_for :to_params
    filters.update_date_format(old_format, new_format)
  end

  def on_tag_renamed(old_name, new_name)
    clear_cached_results_for :to_params
    if index = @tagged_with.index(old_name)
      @tagged_with[index] = new_name
      save!
    end
  end

  def uses?(property_definition)
    used_in_columns_and_sort = [@columns, @sort].flatten.any? do |candidate|
      candidate.to_s.downcase == property_definition.name.downcase
    end
    used_in_columns_and_sort || @filters.uses_property_definition?(property_definition) || group_lanes.uses?(property_definition)
  end

  def uses_card_type?(card_type)
    @filters.uses_card_type?(card_type.name) || group_lanes.uses_card_type?(card_type)
  end

  def uses_property_value?(prop_name, value)
    @filters.uses_property_value?(prop_name, value) || group_lanes.uses_property_value?(prop_name, value)
  end

  def uses_plv?(plv)
    @filters.uses_plv?(plv)
  end

  def uses_card?(card)
    @filters.uses_card?(card)
  end

  def cards_used_sql_condition
    @filters.cards_used_sql_condition
  end

  def project_variables_used
    @filters.project_variables_used
  end

  def uses_from_tree_as_condition?(tree_name)
    @filters.respond_to?(:uses_from_tree_as_condition?) && @filters.uses_from_tree_as_condition?(tree_name)
  end

  def group_by_transition_only_property_definition?
    group_lanes.group_by_transition_only_lane_property_definition?
  end

  def grid_sort_by
    group_lanes.grid_sort_by
  end

  def show_lane(lane_identifier)
    show_dimension :lane, lane_identifier
  end

  def hide_lane(lane_identifier)
    hide_dimension :lane, lane_identifier
  end

  def show_dimension(dimension, identifier)
    self.class.find_or_construct(project, groups.show_dimension_params(dimension, identifier))
  end

  def hide_dimension(dimension, identifier)
    self.class.find_or_construct(project, groups.hide_dimension_params(dimension, identifier))
  end

  def color_by
    group_lanes.color_by
  end

  def aggregate_property
    group_lanes.aggregate_property
  end

  def aggregate_type
    group_lanes.aggregate_type
  end

  def visible_lanes
    group_lanes.visibles(:lane).collect(&:title)
  end

  def viewable_styles
    @workspace.viewable_styles
  end

  def hierarchy?
    @style == CardView::Style::HIERARCHY
  end

  def paginator()
    options = { :page => @page }
    options.merge!(:items_per_page => @cards_per_page) if @cards_per_page
    Paginator.create_with_current_page(card_count, options)
  end
  memoize :paginator

  def color_by_property_definition
    @style.color_by_property_definition(self)
  end

  def action
    'list'
  end

  def requires_tree?
    CardView::Style.require_tree?(self.style)
  end

  def project_name
    project.name
  end

  def project
    Project.current
  end

  def card_selection
    return @card_selection if @card_selection
    if all_cards_selected?
      @card_selection = CardSelection.new(project, self)
    else
      selected_cards = CardSelection.cards_from(project, @selected_cards)
      @card_selection = CardSelection.new(project, selected_cards)
      @card_selection.update_from(self.cards)
    end
    @card_selection
  end

  def invalid_selection?
    @card_selection = card_selection
    selected_card_ids = @selected_cards.blank? ? [] : @selected_cards.split(',')
    is_invalid_selection = @card_selection.count < selected_card_ids.size
    if is_invalid_selection
      are_selected_but_not_in_selection = @card_selection.not_in_selection(selected_card_ids)
      bold_names = are_selected_but_not_in_selection.collect { |card| card.name.bold }
      error_msg = if workspace.tree_workspace?
        "#{'Card'.plural(bold_names.size)} #{bold_names.join(', ')} #{'has'.plural(bold_names.size)} either been removed from the tree or deleted while you were working.  Please make another selection and try again."
      else
        "A selected card has been deleted while you were working.  Please make another selection and try again."
      end
      errors.add_to_base(error_msg)
    end
    is_invalid_selection
  end

  def delete_with_confirmation?
    true
  end

  def tab_view?
    self.favorite.tab_view?
  end

  def tab_view=(value)
    self.favorite.tab_view = value
  end

  def has_valid_sort_order?
    @sort && valid_column?(@sort) && ORDERS.include?(@order.downcase)
  end

  def to_workspace(workspace)
    self.class.find_or_construct(project, to_workspace_params(workspace))
  end

  def to_workspace_params(workspace)
    to_params.merge(:tree_name => workspace)
  end

  def filter_column_query
    conditions = []
    unless tagged_with.blank?
      conditions += Tag.parse(tagged_with).collect{|tag| CardQuery::TaggedWith.new(tag)}
    end
    conditions += filters.as_card_query_conditions

    ##todo: condition empty logic should goes into cardquery to release the burden of card query user
    # 2008-07-21 wpc
    conditions = conditions.compact.empty? ? nil : CardQuery::And.new(*conditions)
    remove_invalid_columns!
    CardQuery.new(:columns => card_query_columns, :conditions => conditions, :order_by => order_by, :fetch_descriptions => fetch_descriptions)
  end
  memoize :filter_column_query

  def list?
    @style == CardView::Style::LIST
  end

  def grid?
    @style == CardView::Style::GRID
  end

  def tree?
    @style == CardView::Style::TREE
  end

  def all_cards_tree
    filters.invalid? ? workspace.empty_tree : workspace.all_cards_tree
  end

  def display_tree
    filters.invalid? ? workspace.empty_tree : workspace.expanded_cards_tree
  end

  def expands
    @expands ||= []
  end

  def clear_expands!
    @expands = []
    project.card_list_views.create_or_update(to_params.merge(:expands => @expands.join(','), :view => {:name => name}))
  end

  def clear_single_expand!(card_number)
    @expands.delete(card_number)
    to_params.merge(:expands => @expands.join(','), :view => {:name => name})
  end

  def order_by
    @style.card_query_order_by(self)
  end

  def interactive_filters
    @filters.is_a?(Filters) ? @filters : []
  end

  def mql_filters
    @filters.is_a?(MqlFilters) ? @filters : nil
  end

  def tagged_with_from_filters
    filter_by_mql? ? mql_filters.as_card_query.tags[:tagged_with].join(",") : @tagged_with
  end

  def mql_filter_value
    mql_filters.to_s if filter_by_mql?
  end

  def filter_by_mql?
    @filters.is_a?(MqlFilters)
  end

  def rank_is_on?
    group_lanes.rank_is_on
  end

  def build_canonical_string
    non_serialized_parameters = {:tab => nil, :action => nil, :all_cards_selected => nil, :expanded => nil, :rank_is_on => nil}
    state_params = to_params.merge(non_serialized_parameters)
    build_canonical_string_for(state_params)
  end

  def wip_limits_for(lane)
    @wip_limits[lane.url_identifier] if @wip_limits && @wip_limits[lane.url_identifier].present?
  end

  def hide_wip_limits?
    @hide_wip_limits.is_a?(String) ? @hide_wip_limits == 'true' : (@hide_wip_limits.nil? ? false : @hide_wip_limits)
  end

  def rename_wip_params(old_name, new_name)
    @wip_limits && @wip_limits[old_name] && @wip_limits[new_name] = @wip_limits.delete(old_name)
  end

  protected
  def build_canonical_string_for(params)
    remove_style_param_if_it_is_the_only_one(params).joined_ordered_values_by_smart_sorted_keys
  end

  def self.with_users_used_in_filter_properties(view, &block)
    users = []
    current_filters = view.filters
    if current_filters.respond_to?(:each)
      current_filters.each do |filter|
        if filter.property_definition.instance_of?(UserPropertyDefinition)
          user = User.find_by_login(filter.value) unless filter.value.blank?
          users << user if user
        end
      end
    elsif current_filters.respond_to?(:mql_conditions)
      properties_to_values = current_filters.mql_conditions.property_definitions_with_values
      properties_to_values.each do |property, values|
        next unless property.instance_of?(UserPropertyDefinition)
        values.each do |value|
          users << User.find(value.field_value)
        end
      end
    elsif current_filters.respond_to?(:filters_for_type)
      all_tree_filters = current_filters.included_filters.values
      all_tree_filters.each do |tree_filters|
        tree_filters.each do |filter|
          if filter.property_definition.instance_of?(UserPropertyDefinition)
            user = User.find_by_login(filter.value) unless filter.value.blank?
            users << user if user
          end
        end
      end
    end
    users.uniq.each { |user| yield user }
  end

  private

  def sanitize(name)
    html_escape = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;' }
    name.to_s.gsub(/[&"><]/) { |special| html_escape[special] }
  end

  def translate_old_aggregate_params(params)
    if params[:aggregate_type].nil? || params[:aggregate_type].is_a?(String)
      params[:aggregate_type] = {:column => params[:aggregate_type]}
      params[:aggregate_property] = {:column => params[:aggregate_property]}
    end
  end

  def detect_maximized_tab
    self.errors.add_to_base("Maximized views cannot be saved as tabs") if (self.tab_view? && self.maximized)
  end

  def valid_column?(column)
    valid_columns.any?{|valid_column| valid_column.downcase == column.to_s.downcase}
  end

  def valid_columns
    %w(number name project_card_rank) + filters.column_properties(:without_smart_order => true).collect(&:name)
  end
  memoize :valid_columns

  def clean_up_params
    self.params = to_params
    @style.clear_not_applicable_params!(self.params)
    cleanup_wip_limits(self.params)
    self.params.delete(:tab)
    self.params.delete(:action)
    self.params.delete(:all_cards_selected)
    self.params.delete(:expanded)
    self.params.delete(:rank_is_on)
  end

  def build_canonical_strings
    self.canonical_string = build_canonical_string_for(self.params)
  end

  def serialize_params
    self.params = YAML.dump(self.params)
  end

  def remove_style_param_if_it_is_the_only_one(params)
    if (params.values.compact.size == 1 && params[:style] == 'list')
      params.delete(:style)
    end
    params
  end

  def add_uniqueness_error(existing_view_name, options={})
    errors.add_to_base("Current view cannot be saved because it matches the #{existing_view_name.bold} view.")
  end

  def save_favorite
    self.favorite.update_attributes(:favorited_id => self.id) if favorite
    clear_cached_results_for(:to_params)
  end

  def equal_param_hashes(one, another)
    return false unless [one, another].all? { |h| h.respond_to?(:keys) }
    return false unless one.keys.collect{|k| k.to_s.downcase}.sort == another.keys.collect{|k| k.to_s.downcase}.sort
    one.all? do |key, value|
      next true if key.to_s.downcase == 'tab'
      if value.is_a?(Hash)
        equal_param_hashes(value, lookup_hash_value(key, another))
      else
        split_and_compare_param_value(value) == split_and_compare_param_value(lookup_hash_value(key, another))
      end
    end
  end

  def lookup_hash_value(key, hash)
    pair = lookup_hash_entry(key, hash)
    pair[1] if pair
  end

  def lookup_hash_entry(key, hash)
    hash.detect{|k, v| k.to_s.downcase == key.to_s.downcase}
  end

  def split_and_compare_param_value(value)
    return value if value.is_a?(Hash)
    value = value.to_s.split(',') unless value.is_a?(Array)
    value.collect { |v| v.strip.downcase }.sort
  end

  def card_query_columns
    (['Number', 'Name'] + columns).map(&:downcase).uniq.collect { |c| CardQuery::Column.new(c) }
  end

  def destroy_favorite
    favorite.destroy if favorite
  end

  def cleanup_wip_limits(parameters)
    return unless parameters[:wip_limits]
    if parameters[:group_by].nil? || parameters[:group_by][:lane].nil?
      parameters.delete(:wip_limits)
      return
    end
    cleanup_lanes(parameters)
    parameters[:wip_limits].keys.each do |lane_name|
      wip_limit = parameters[:wip_limits][lane_name]
      parameters[:wip_limits].delete(lane_name)  if wip_limit[:type].downcase.eql?('sum') && (!is_whole_number?(wip_limit[:limit]) || wip_limit[:property].nil?)
      parameters[:wip_limits].delete(lane_name)  if wip_limit[:type].downcase == 'count' && (!is_whole_number?(wip_limit[:limit]) || wip_limit[:limit].to_i > 500)
    end
  end

  def is_whole_number?(string)
    string = string.class.eql?(String) ? string : string.to_s
    string =~ /^\d+$/
  end

  def cleanup_lanes(parameters)
    lane_names = parameters[:wip_limits].keys
    enumeration_values = group_lanes.lane_property_definition.lane_values.map {|val| val.last.downcase}
    lane_names.each do |lane|
      parameters[:wip_limits].delete(lane) unless enumeration_values.include?(lane.downcase) && is_lane_value?(lane.downcase)
    end
  end

  def is_lane_value?(lane)
    group_lanes.lanes.collect(&:url_identifier).any? {|lane_name| lane_name && lane_name.downcase == lane}
  end
end

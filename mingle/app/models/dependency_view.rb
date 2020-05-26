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

class DependencyView < ActiveRecord::Base
  serialize :params, Hash

  belongs_to :project
  belongs_to :user
  validates_uniqueness_of :user_id, :scope => :project_id
  include SqlHelper

  PARAM_NAMES = [:filter, :sort, :dir, :collapsed]
  PARAM_VALUES = {
    :filter => ['raising', 'resolving'],
    :dir => ['asc', 'desc'],
    :sort => [ 'number', 'name', 'desired_end_date', 'raising_project', 'resolving_project', 'created_at', 'raising_user'],
    :collapsed => [Dependency::NEW.downcase, Dependency::ACCEPTED.downcase, Dependency::RESOLVED.downcase, 'none']
  }
  PARAM_DEFAULT_VALUES = {
    :filter => 'resolving',
    :dir => 'asc',
    :sort => 'number',
    :collapsed => ['none']
  }
  COLUMNS = {
    :values => ['desired_end_date', 'created_at', 'raising_project', 'resolving_project', 'raising_user', 'raising_card', 'resolving_cards'],
    :default => {
      :raising => ['resolving_project', 'raising_card', 'resolving_cards'],
      :resolving => ['desired_end_date', 'raising_project', 'raising_user', 'resolving_cards']
    }
  }

  COLUMN_DISPLAY_NAMES = {
    'desired_end_date' => 'Desired Completion Date',
    'raising_project' => 'Raised by',
    'resolving_project' => 'Resolved by',
    'created_at' => 'Date Raised',
    'raising_user' => 'Raising User',
    'raising_card' => 'Raising Card',
    'resolving_cards' => 'Resolving Card(s)'
  }

  PARAM_NAMES.each do |name|
    define_method(name) do
      params[name] || PARAM_DEFAULT_VALUES[name]
    end
  end

  def columns
    params[:columns] ||= {}
    filter_column_values(params[:columns][self.filter.to_sym]) || COLUMNS[:default][self.filter.to_sym]
  end

  def columns=(cs)
    return if cs.blank?
    values = filter_column_values(cs[self.filter.to_sym])
    return if values.blank?
    params[:columns] = {} unless params[:columns].is_a? Hash #for migrating data. The columns attr is currently an array in the db.
    params[:columns][self.filter.to_sym] = values
  end

  def column_values
    COLUMNS[:values]
  end

  before_create :init_params

  class << self
    def current
      return new(:params => {}) if User.current.anonymous?
      find_or_create_by_user_id(User.current.id)
    end
  end

  def resolving?
    self.filter == "resolving"
  end

  def is_collapsed? status
    return self.collapsed.include?(status.downcase)
  end

  def column_display_name(column)
    COLUMN_DISPLAY_NAMES[column.to_s]
  end

  def update_params(params)
    PARAM_NAMES.each do |name|
      if name == :collapsed
        c = params[name] & PARAM_VALUES[name]
        self.params[name] = c unless c.blank?
      else
        self.params[name] = params[name] if PARAM_VALUES[name].include?(params[name])
      end
    end
    self.columns = params[:columns]
    self.save! if self.user_id
    self
  end

  def dependencies_with_status(status, options={})
    filtered_dependencies(status, sort_options.merge(options))
  end

  def filtered_dependencies(status, options={})
    Dependency.find_by_sql(sanitize_sql(sql(status, options)))
  end

  def sort_column_params(column)
    return unless PARAM_VALUES[:sort].include?(column)
    if column == self.sort
      params.merge(:dir => self.dir == 'asc' ? 'desc' : 'asc', :sort => column)
    else
      params.merge(:dir => PARAM_DEFAULT_VALUES[:dir], :sort => column)
    end
  end

  def project
    Project.current
  end

  def requires_tree?
    false
  end

  def page
    nil
  end

  def style
    false
  end

  def to_params
    {}
  end

  def sql(status, options)
    sql = %{
      SELECT "dep".*, ROW_NUMBER() OVER (#{order(options)}) as "ROW" from #{Dependency.quoted_table_name} "dep"
      LEFT JOIN #{Project.quoted_table_name} "raising_projects"
        ON "dep".raising_project_id = "raising_projects".id
      LEFT JOIN #{Project.quoted_table_name} "resolving_projects"
        ON "dep".resolving_project_id = "resolving_projects".id
      INNER JOIN #{User.quoted_table_name} "raising_users"
        ON "dep".raising_user_id = "raising_users".id
      WHERE "dep".#{self.filter}_project_id = '#{self.project.id}'
      AND "dep".status = '#{status}'
      #{order(options)}
    }
    if options[:limit]
      if options[:after_id]
        sql = %{
          WITH "selectedRows" AS (
              #{sql}
            )
          SELECT "selectedRows".* from "selectedRows"
            WHERE "selectedRows"."ROW" > (SELECT "selectedRows"."ROW" FROM "selectedRows" WHERE "selectedRows".id=#{options[:after_id]})
            AND "selectedRows"."ROW" <= ((SELECT "selectedRows"."ROW" FROM "selectedRows" WHERE "selectedRows".id=#{options[:after_id]}) + #{options[:limit]})
         }
      else
        sql = %{
            SELECT * FROM (
              #{sql}
            ) "selectedRows" WHERE "selectedRows"."ROW" <= #{options[:limit]}
          }
      end
    end
    sql
  end

 def sort_options
    sort_options = {}
    sort_field = self.sort
    if sort_field == 'raising_user'
      sort_options[:sort_column] = quoted_column_name('name')
      sort_options[:sort_table_name] = User.quoted_table_name
      sort_options[:sort_table_alias] = 'raising_users'
    elsif sort_field == 'raising_project'
      sort_options[:sort_column] = quoted_column_name('name')
      sort_options[:sort_table_name] = Project.quoted_table_name
      sort_options[:sort_table_alias] = 'raising_projects'
    elsif sort_field == 'resolving_project'
      sort_options[:sort_column] = quoted_column_name('name')
      sort_options[:sort_table_name] = Project.quoted_table_name
      sort_options[:sort_table_alias] = 'resolving_projects'
    else
      sort_options[:sort_column] = quoted_column_name(sort_field)
      sort_options[:sort_table_name] = Dependency.quoted_table_name
      sort_options[:sort_table_alias] = 'dep'
    end
    sort_options[:sort_direction] = self.dir.upcase
    sort_options
  end

  def order(options)
    return '' if !(options[:sort_table_alias] && options[:sort_column] && options[:sort_direction])
    %Q{ ORDER BY "#{options[:sort_table_alias]}".#{options[:sort_column]} #{options[:sort_direction]}, "dep".created_at #{options[:sort_direction]} }
  end

  private

  def quoted_column_name(original_name)
    self.class.connection.quote_column_name(original_name)
  end

  def filter_column_values(column_values)
    column_values & COLUMNS[:values]
  end

  def init_params
    self.params ||= {}
  end
end

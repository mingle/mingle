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

require 'mql'
require 'cta/list'
require 'cta/property_substitution'
require 'cta/project_variables'
require 'cta/enum_prop_comparison'

module CTA
  class UnsupportedSyntax < StandardError; end

  DEFAULT_TRANSFORMERS = [
    PropertySubstitution,
    ProjectVariables,
    EnumPropComparison,
    List,
  ]

  module_function

  def transformers(options={})
    options[:add_transformers] ||= []
    DEFAULT_TRANSFORMERS + options[:add_transformers]
  end

  def parse(mql, options={})
    transformers(options).inject(::Mql.parse(mql)) do |ast, t|
      t.new.apply(ast)
    end
  end
end

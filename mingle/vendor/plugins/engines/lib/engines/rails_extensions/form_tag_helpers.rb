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

# == Using plugin assets for form tag helpers
#
# It's as easy to use plugin images for image_submit_tag using Engines as it is for image_tag:
#
#   <%= image_submit_tag "my_face", :plugin => "my_plugin" %>
#
# ---
#
# This module enhances one of the methods from ActionView::Helpers::FormTagHelper:
#
#  * image_submit_tag
#
# This method now accepts the key/value pair <tt>:plugin => "plugin_name"</tt>,
# which can be used to specify the originating plugin for any assets.
#
module Engines::RailsExtensions::FormTagHelpers
	def self.included(base)
		base.class_eval do
			alias_method_chain :image_submit_tag, :engine_additions
		end
	end
	
	# Adds plugin functionality to Rails' default image_submit_tag method.
	def image_submit_tag_with_engine_additions(source, options={})
		options.stringify_keys!
		if options["plugin"]
			source = Engines::RailsExtensions::AssetHelpers.plugin_asset_path(options["plugin"], "images", source)
			options.delete("plugin")
		end
		image_submit_tag_without_engine_additions(source, options)
	end
end

module ::ActionView::Helpers::FormTagHelper #:nodoc:
  include Engines::RailsExtensions::FormTagHelpers
end


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

require 'sprockets'
require 'mingle_configuration'

unless Rails.env.production?
  require 'sass'
  require 'compass'
  require 'susy'
  require "sprockets-sass"
end

module MingleSprocketsConfig
  module_function

  class AssetsServer
    def initialize(app)
      @app = app
    end

    def sprockets_assets_pattern
      /\/(#{MingleSprocketsConfig.assets.join("|")})$/
    end

    def call(env)
      if env['PATH_INFO'] =~ sprockets_assets_pattern
        env['PATH_INFO'] = File.basename(env['PATH_INFO'])
        MingleSprocketsConfig.env.call(env)
      else
        @app.call(env)
      end
    end
  end

  def env
    @env ||= create_env
  end

  def manifest
    @manifest ||= Sprockets::Manifest.new(self.env, assets_path)
  end

  def assets_path
    @assets_path ||= if $servlet_context
      path = File.join($servlet_context.get_init_parameter("public.root"), "/assets").to_java(:string)
      $servlet_context.get_real_path(path)
    else
      Rails.root.join("public", "assets").to_s
    end
  end

  def rewrite_asset_path(source, production_assets=production_assets?)
    if production_assets
      digest_for(source.to_s)
    end
  end

  def init
    ActionController::Dispatcher.middleware.use(AssetsServer) unless production_assets?
  end

  def clean
    manifest.clobber
  end

  def build
    clean
    manifest.compile(self.assets)
  end

  def assets
    Dir.glob(Rails.root.join("app/assets/**/*.{js,css}")).to_a.map {|f| File.basename(f)}
  end

  def production_assets?
    Rails.env.test? || Rails.env.production?
  end

  def controller_spec_css?(name)
    self.manifest.assets["#{name}.css"]
  end

  def digest_for(source)
    logical_path = File.basename(source)
    if digest = self.manifest.assets[logical_path]
      File.join('/assets', digest)
    else
      Rails.logger.debug("no digest found for #{source}")
      nil
    end
  end

  def create_env
    Sprockets::Environment.new(Rails.root) do |env|
      env.append_path 'app/assets/javascripts'
      env.append_path 'app/assets/stylesheets'
      env.append_path 'public/javascripts'
      # setup asset_path for compiling with scss
      env.context_class.class_eval do
        def asset_path(path, options = {})
          path
        end
      end

      if Rails.logger
        env.logger = Rails.logger
      end
    end
  end

end

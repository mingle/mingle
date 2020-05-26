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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the MIT License (http://www.opensource.org/licenses/mit-license.php)

class OauthClientsController < ApplicationController

  include Oauth2::Provider::SslHelper

  def index
    @oauth_clients = Oauth2::Provider::OauthClient.all.sort{|a, b| a.name.casecmp(b.name)}
    respond_to do |format|
      format.html
      format.xml  { render :xml => @oauth_clients.to_xml(:root => 'oauth_clients', :dasherize => false) }
    end
  end

  def show
    @oauth_client = Oauth2::Provider::OauthClient.find(params[:id])
    respond_to do |format|
      format.html
      format.xml  { render :xml => @oauth_client.to_xml(:dasherize => false) }
    end
  end

  def new
    @oauth_client = Oauth2::Provider::OauthClient.new
  end

  def edit
    @oauth_client = Oauth2::Provider::OauthClient.find(params[:id])
  end

  def create
    @oauth_client = Oauth2::Provider::OauthClient.new(params[:oauth_client])

    respond_to do |format|
      if @oauth_client.save
        flash[:notice] = 'OAuth client was successfully created.'
        format.html { redirect_to :action => 'index' }
        format.xml  { render :xml => @oauth_client, :status => :created, :location => @oauth_client }
      else
        flash.now[:error] = @oauth_client.errors.full_messages
        format.html { render :action => "new" }
        format.xml  { render :xml => @oauth_client.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @oauth_client = Oauth2::Provider::OauthClient.find(params[:id])

    respond_to do |format|
      if @oauth_client.update_attributes(params[:oauth_client])
        flash[:notice] = 'OAuth client was successfully updated.'
        format.html { redirect_to :action => 'index' }
        format.xml  { head :ok }
      else
        flash.now[:error] = @oauth_client.errors.full_messages
        format.html { render :action => "edit" }
        format.xml  { render :xml => @oauth_client.errors, :status => :unprocessable_entity }
      end
    end

  end

  def destroy
    @oauth_client = Oauth2::Provider::OauthClient.find(params[:id])
    @oauth_client.destroy

    respond_to do |format|
      flash[:notice] = 'OAuth client was successfully deleted.'
      format.html { redirect_to(oauth_clients_url) }
      format.xml  { head :ok }
    end
  end
end

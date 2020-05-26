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

class TodosController < ApplicationController

  allow :get_access_for => [:index],
        :put_access_for => [:create, :update],
        :delete_access_for => [:delete, :bulk_delete],
        :redirect_to => {:action => :index}

  before_filter :require_user

  def require_user
    @user = User.find_by_id_exclude_system(params[:user_id])
  end

  def index
    respond_to do |format|
      format.json { render :json => @user.todos.ranked.to_json }
    end
  end

  def create
    todo = @user.todos.create! :content => params[:content]
    respond_to do |format|
      format.json { render :json => todo.to_json }
    end
  end

  def update
    todo = @user.todos.find(params[:id])

    [:content, :done, :position].each do |prop|
      todo.update_attribute(prop, params[prop]) if params[prop]
    end

    respond_to do |format|
      format.json { render :json => todo.to_json }
    end
  end

  def delete
    @user.todos.find(params[:id]).destroy
    respond_to do |format|
      format.json { render :json => {:deleted => params[:id]}.to_json }
    end
  end

  def bulk_delete
    params[:ids].each_slice(100) do |ids|
      # use faster delete_all since the Todo model is so simple
      Todo.delete_all(["id in (?)", ids])
    end

    index
  end

  # naive acts_as_list impl - doesn't scale, updates all rows
  # todo: use similar impl as ranked-model, but for rails 2.3
  def sort
    order = params[:todos].map(&:to_i)
    @user.todos.each do |t|
      i = order.index(t.id) + 1
      t.update_attributes!(:position => i) unless i == t.position
    end

    index
  end
end

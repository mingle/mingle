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

class ChecklistItemsController < ProjectApplicationController

  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["create", "delete", "mark", "update", "reorder"]

  def create
    if card = @project.cards.find_by_number(params[:card_number])
      item_position = card.incomplete_checklist_items.length
      item = card.checklist_items.build(:text => params[:item], :project_id => @project.id, :completed => false, :position => item_position)
      if item.save
        add_monitoring_event("created_checklist_item")
        r = { :item_id => item.reload.id, :position => item.position }
        render :json => r.to_json, :status => :created
      else
        render :status => :bad_request, :text => item.errors.full_messages.join("\n")
      end
    else
      render :nothing => true, :status => :not_found
    end
  end

  def reorder
    unless params[:items].nil? || params[:items].empty?
      params[:items].each_with_index do |item, index|
        i = ChecklistItem.find(item)
        i.position = index
        i.save
      end
      render :nothing => true, :status => :ok
    else
      render :status => :bad_request, :text => "No items to order"
    end
  end

  def delete
    checklist_item = ChecklistItem.find_by_id(params[:item_id])
    checklist_item.destroy if checklist_item
    render :nothing => true, :status => :ok
  end

  def mark
    item = ChecklistItem.find_by_id(params[:item_id])
    if item.nil?
      card = @project.cards.find_by_number(params[:card_number])
      item = card.checklist_items.build(:text => params[:item_text],  :project_id => @project.id )
    end

    params[:completed] == "true" ? item.mark_complete : item.mark_incomplete

    add_monitoring_event("checked_checklist_item", { :completed => params[:completed] })
    render :json => { :item_id => item.reload.id }.to_json, :status => :ok
  end

  def update
    item = ChecklistItem.find_by_id(params[:item_id])
    if item.nil?
      card = @project.cards.find_by_number(params[:card_number])
      item = card.checklist_items.build(  :project_id => @project.id, :completed => params[:item_completed])
    end
    item.text = params[:item_text]

    if item.save
      render :json => {:item_id => item.reload.id }.to_json, :status => :ok
    else
      render :status => :bad_request, :text => item.errors.full_messages.join("\n")
    end
  end

end

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

class AddMissingIndicesOnFksAndFrequentlyQueriedColumns < ActiveRecord::Migration
  def self.up
    if ActiveRecord::Base.table_name_prefix.blank?
      add_index :asynch_requests, :user_id, :name => 'idx_async_req_on_user_id'
      add_index :asynch_requests, [:user_id, :project_identifier], :name => 'idx_async_req_on_user_proj'
    
      add_index :attachings, [:attachable_id, :attachable_type], :name => 'idx_attaching_on_id_and_type'

      add_index :attachments, :project_id, :name => 'idx_atchmnt_on_proj_id'
    
      add_index :card_defaults, [:card_type_id, :project_id], :name => 'idx_card_def_on_ct_and_proj_id'
    
      add_index :card_revision_links, [:card_id, :revision_id], :name => 'idx_crl_on_card_and_rev_id'
    
      add_index :card_types, :project_id, :name => 'idx_card_types_on_proj_id'
    
      add_index :events, :project_id, :name => 'idx_events_on_proj_id'
    
      add_index :favorites, [:project_id, :favorited_type, :favorited_id], :name => 'idx_fav_on_type_and_id'
    
      add_index :history_subscriptions, [:project_id, :user_id], :name => 'idx_hist_sub_on_proj_user'
    
      add_index :page_versions, [:project_id, :page_id, :version], :name => 'idx_page_ver_on_page_ver'
    
      add_index :projects_members, [:project_id, :user_id], :name => 'idx_proj_memb_on_proj_user'
    
      add_index :property_type_mappings, [:card_type_id, :property_definition_id], :name => 'idx_ctpd_on_ct_and_pd_id'
    
      add_index :revisions, :number, :name => 'idx_rev_on_number'
      add_index :revisions, :commit_time, :name => 'idx_rev_on_commit_time'
      add_index :revisions, :project_id, :name => 'idx_rev_on_proj_id'
    
      add_index :searchable_term_lists, [:project_id, :searchable_id, :searchable_type], :name => 'idx_stl_on_search_id_and_type'
    
      add_index :stale_aggregates, [:project_id, :card_id, :aggregate_prop_def_id], :name => 'idx_stagg_on_card_and_agg_pd'
    
      add_index :taggings, [:taggable_id, :taggable_type], :name => 'idx_tagging_on_id_and_type'
    
      add_index :transition_actions, [:executor_id, :executor_type], :name => 'idx_tact_on_exec_id_and_type'
    
      add_index :transition_prerequisites, :transition_id, :name => 'idx_tpre_on_trans_id'
    
      add_index :transitions, :project_id, :name => 'idx_trans_on_proj_id'
    
      add_index :variable_bindings, [:project_variable_id, :property_definition_id], :name => 'idx_var_bind_on_pv_and_pd_id'
    end  
  end

  def self.down
  end
end

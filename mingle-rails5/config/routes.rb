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

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  # get '/hello', to: 'welcome#hello'
  root 'projects#index', :conditions => {:method => :get}

  scope :user_display_preference, controller: :user_display_preference do
    post 'update_user_display_preference'
    post 'update_show_deactived_users', action: :update_show_deactivated_users
    post 'update_holiday_effects_preference'
    post 'update_user_project_preference'
  end

  get '/saas_tos/show', to: 'saas_tos#show'
  get '/license/warn', to: 'license#warn'
  get '/license/show', to: 'license#show'


  get '/account/edit', to: 'account#edit'
  get '/account/downgrade', to: 'account#downgrade'

  post '/saas_tos/accept', to: 'saas_tos#accept'

  namespace :api, path: 'api/internal' do
    resources :programs, only: [:index] do
      resources :backlog_objectives, except: [:edit, :new, :create], param: :number do
        post :plan, :change_plan, on: :member
        collection do
          post :reorder, :create
        end
      end

      resources :objective_property_definitions, only: [:create]
      resources :objective_types, only: [:update]

      resources :program_memberships, except: [:edit, :new] do
        post :create
        collection do
          post :bulk_remove, :bulk_update
        end
      end
    end
    resources :users, except: [:new, :create, :edit]

    get '/users/:user_login/projects', to: 'users#projects', as: :user_projects
  end

  resources :projects

  get '/programs/:program_id/backlog_objectives', to: 'backlog_objectives#index', as: :program_backlog_objectives

  resources :install, only: [:index]
  get '/projects/:project_id/team/show_user_selector', to: 'team#show_user_selector'

  resources :programs, only: [:index] do
    resources :plan, only: [:index]
    get :team, to: 'program_memberships#index', as: :memberships, get_with_projects: true
    get :projects, to: 'program_projects#index', as: :projects
    get :dependencies, to: 'program_dependencies#index', as: :dependencies
    get :settings, to: 'program_settings#index', as: :settings
  end

  resource :profile, controller: :profile do
    get 'login', action: :login, as: 'login'
    post 'login', action: :login
    get 'logout', action: :login, as: 'logout'
    get 'show/:user_id', action: :show, as: :user
    get 'forgot_password', action: :forgot_password
  end

  resource :feedback, only: [:new, :create]
  get 'about/contact_us', to: 'about#contact_us', as: :contact_us


  if Rails.env.test?
    get '/call_me_in_test', to: 'dummy#call_me_in_test'
    post '/call_me_in_test', to: 'dummy#call_me_in_test'
    get '/api/:api_version/call_me_in_test', to: 'dummy#call_me_in_test', format: 'xml'
    post '/api/:api_version/call_me_in_test', to: 'dummy#call_me_in_test', format: 'xml'
    get '/raise_exception_for_test', to: 'dummy#raise_exception_for_test'
    get '/call_me_in_test', to: 'dummy#call_me_in_test'
    get '/check_in_test', to: 'dummy_planner_application#check_in_test'
  end
end

/*
*  Copyright 2020 ThoughtWorks, Inc.
*
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/
import utils from './utils/objectives_util'
import ObjectivesErrorHandler from './error_handler/objective_error_handler'
import Api from './api'

export default class Objectives extends Api {
  constructor(baseUrl, csrfToken, tracker, errorHandler = ObjectivesErrorHandler) {
    super(baseUrl, csrfToken, errorHandler, tracker);
  }

  reorder(params) {
    return this.client.post(`${this.baseUrl}/reorder`, params);
  }

  fetchFor(number) {
    return new Promise((resolver) => {
      this.client.get(`${this.baseUrl}/${number}`).then((response) => {
        resolver({success: true, data: response.data})
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'fetch');
      });
    });
  }

  delete(number) {
    return new Promise((resolver) => {
      this.client.delete(`${this.baseUrl}/${number}`).then(() => {
        this.tracker.track('program_delete_objective');
        resolver({success: true});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'delete');
      });
    });
  }

  update(objective) {
    return new Promise((resolver) => {
      this.client.put(`${this.baseUrl}/${objective.number}`, {backlog_objective: objective}).then((response) => {
        resolver({success: true, data: response.data})
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'update');
      });
    });
  }

  planObjective(number) {
    return new Promise((resolver) => {
      this.client.post(`${this.baseUrl}/${number}/plan`, {}).then((response) => {
        this.tracker.track('program_plan_objective');
        utils.redirect(response.data.redirect_url);
        resolver({success: true});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'plan');
      });
    });
  }

  changePlan(number) {
    return new Promise((resolver) => {
      this.client.post(`${this.baseUrl}/${number}/change_plan`, {}).then((response) => {
        this.tracker.track('program_change_objective_plan');
        utils.redirect(response.data.redirect_url);
        resolver({success: true});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'plan');
      });
    });
  }

  create(objectiveData){
    return new Promise((resolver) => {
      this.client.post(this.baseUrl, {backlog_objective:objectiveData}).then((response)=>{
        this.tracker.track('program_create_objective');
        resolver({success: true, data: response.data});
      }).catch((error)=> {
        this.errorHandler.handle(error.response, resolver, 'create');
      });
    });
  }
}

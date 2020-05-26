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
import UserErrorHandler from "./error_handler/user_error_handler";
import Api from "./api";

export default class User extends Api {
  constructor(baseUrl, csrfToken, programId, errorHandler = UserErrorHandler) {
    super(baseUrl, csrfToken, errorHandler);
    this.programId = programId;
  }

  fetchUsers(){
    return new Promise((resolver) => {
      this.client.get(`${this.baseUrl}`, {params: {exclude_light_users: true}}).then((response) => {
        resolver({success: true, users:response.data});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'fetchUsers');
      });
    });
  }
  fetchProjects(userLogin){
    return new Promise((resolver) => {
      this.client.get(`${this.baseUrl}/${userLogin}/projects?program_id=${this.programId}`).then((response) => {
        resolver({success: true, data:response.data});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'fetchProjects');
      });
    });
  }

}
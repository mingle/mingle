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
import ProgramTeamErrorHandler from "./error_handler/program_team_error_handler";
import Api from "./api";

export default class ProgramTeam extends Api {
  constructor(baseUrl, csrfToken, errorHandler = ProgramTeamErrorHandler) {
    super(baseUrl, csrfToken, errorHandler)
  }

  bulkRemove(usersLogin){
    return new Promise((resolver) => {
      this.client.post(`${this.baseUrl}/bulk_remove`, {members_login: usersLogin}).then((response) => {
        resolver({success: true, message:response.data});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'bulkRemove');
      });
    });
  }

  addMember(userLogin, userRole){
    return new Promise((resolver) => {
      this.client.post(`${this.baseUrl}`,{user_login: userLogin, role: userRole}).then((response) => {
        resolver({success: true, user:response.data});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'addMember');
      });
    });
  }

  bulkUpdate(logins, role){
    return new Promise((resolver) => {
      this.client.post(`${this.baseUrl}/bulk_update`, {members_login: logins, role: role}).then((response) => {
        resolver({success: true, message:response.data.message});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'bulkUpdate');
      });
    });
  }

}

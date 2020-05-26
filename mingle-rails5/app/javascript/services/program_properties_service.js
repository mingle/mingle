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
import Api from "./api";
import ProgramPropertiesErrorHandler from "./error_handler/program_properties_error_handler";

export default class ProgramProperties extends Api {
  constructor(programIdentifier, csrfToken, errorHandler = ProgramPropertiesErrorHandler) {
    super(`/api/internal/programs/${programIdentifier}/objective_property_definitions`, csrfToken, errorHandler)
  }

  create(property){
    return new Promise((resolver) => {
      this.client.post(`${this.baseUrl}`,{property: property}).then((response) => {
        resolver({success: true, property:response.data});
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'create');
      });
    });
  }
}

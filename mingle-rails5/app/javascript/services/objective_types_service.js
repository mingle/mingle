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
import ObjectiveTypesErrorHandler from "./error_handler/objective_types_error_handler";

export default class ObjectiveTypes extends Api {
  constructor(programIdentifier, csrfToken, errorHandler = ObjectiveTypesErrorHandler) {
    super(`/api/internal/programs/${programIdentifier}/objective_types`, csrfToken, errorHandler)
  }

  update(objectiveType) {
    return new Promise((resolver) => {
      this.client.put(`${this.baseUrl}/${objectiveType.id}`, {objective_type: objectiveType}).then((response) => {
        resolver({success: true, objectiveType: response.data})
      }).catch((error) => {
        this.errorHandler.handle(error.response, resolver, 'update');
      });
    });
  }
}

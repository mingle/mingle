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
const ACTION_NOUN_TO_ACTION_VERB = {
  update: 'updating',
};
export default class ObjectiveTypesErrorHandler {
  handle(response, callback, action) {
    switch (response.status) {
      case 404:
        callback({success: false, error: 'ObjectiveType not found.'});
        break;
      case 422:
        callback({success: false, error: response.data});
        break;
      default:
        callback({
          success: false,
          error: `Something went wrong while ${ACTION_NOUN_TO_ACTION_VERB[action]} objective default.`
        });
    }
  };
}
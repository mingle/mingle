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
import ProgramSettings from '../../../../app/javascript/components/program_settings/ProgramSettings'
import assert from "assert";
import sinon from 'sinon';
import {shallow, createLocalVue} from '@vue/test-utils'

const localVue = createLocalVue();

describe('ObjectiveDefault.vue', () => {
  let programSettingsComponent, storeDispatchStub;
  let sandbox = sinon.createSandbox();

  beforeEach(function () {
    storeDispatchStub = sandbox.stub();
    programSettingsComponent = shallow(ProgramSettings, {
      localVue,
      mocks: {
        $store: {
          state: {
            objectiveTypes: {
              objectiveTypes: []
            }
          }
        }
      }
    })
  });

  describe('Methods', () => {
    it('updateMessage sets message data', () => {
      programSettingsComponent.setData({message: {}});
      programSettingsComponent.vm.updateMessage({type: 'success', text: 'Success Message'});

      assert.deepEqual(programSettingsComponent.vm.message, {type: 'success', text: 'Success Message'});
    });
  });
});
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
import ObjectiveProperties from '../../../../app/javascript/components/objectives/ObjectiveProperties.vue'
import Vue from 'vue'
import assert from "assert";
import vSelect from 'vue-select';
Vue.component('v-select', vSelect);
import {mount, createLocalVue } from '@vue/test-utils'

const localVue = createLocalVue();

describe('ObjectiveProperties', () => {
  let objectivePropertiesComponent, objectiveProperties;
  beforeEach(function () {
    objectiveProperties = {
      Size:{name:'Size', value: 1, allowed_values:[0,1,2,3,4]},
      Value:{name:'Value', value:2, allowed_values:[0,1,2,3,4]}
    };
    objectivePropertiesComponent = mount(ObjectiveProperties,
        {
          propsData: {objectiveProperties: objectiveProperties},
          localVue: localVue,
          mocks: {
            $store: {state: {toggles: {readOnlyModeEnabled: false}}}
          }
        });
  });

  describe('Renders', function () {
    it('objective properties', () => {
      let objectiveContent = objectivePropertiesComponent.find('.objective-properties-container');
      assert.equal('1', objectiveContent.find('.objective-property-size .selected-tag').text().trim());
      assert.equal('Size:', objectiveContent.find('.objective-property-size strong').text().trim());
      assert.equal('2', objectiveContent.find('.objective-property-value .selected-tag').text().trim());
      assert.equal('Value:', objectiveContent.find('.objective-property-value strong').text().trim());
    });
  });
});

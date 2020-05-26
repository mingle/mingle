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
import ObjectiveProperty from '../../../../app/javascript/components/objectives/ObjectiveProperty.vue'
import assert from 'assert'
import {mount} from '@vue/test-utils'

describe('ObjectiveProperty.vue', function () {
  beforeEach(() => {
    this.objectivePropertyComponent = mount(ObjectiveProperty, {
      propsData: {
        objectiveProperty: {name: 'Size', value: 1, allowed_values: [0, 1, 2, 3]},
      },
      mocks: {$store: {state: {toggles: {readOnlyModeEnabled: false}}}}
    });
  });

  describe('Data', () => {
    it('should set property value as selected data', () => {
      assert.strictEqual(this.objectivePropertyComponent.vm.selected, 1);
    });

    it('should selected data to empty when property value is defined', () => {
      this.objectivePropertyComponent = mount(ObjectiveProperty, {
        propsData: {objectiveProperty: {name: 'Size', allowed_values: [0, 1, 2, 3]}},
        mocks: {$store: {state: {toggles: {readOnlyModeEnabled: false}}}}
      });
      assert.strictEqual(this.objectivePropertyComponent.vm.selected, '');
    });
  });

  describe('Renders', () => {
    it('objective property element with property name as class', () => {
      assert.ok(this.objectivePropertyComponent.find('.objective-property.objective-property-size').exists());
      this.objectivePropertyComponent.setProps({objectiveProperty: {name: 'value', allowed_values: [0, 1, 2, 3]}});

      assert.ok(this.objectivePropertyComponent.find('.objective-property.objective-property-value').exists());
    });

    it('objective property name', () => {
      let objectivePropertyElement = this.objectivePropertyComponent.find('.objective-property.objective-property-size');
      assert.equal(objectivePropertyElement.find('.objective-property-name').text(), 'Size:');
    });

    it('selected value of objective', () => {
      let objectivePropertyElement = this.objectivePropertyComponent.find('.objective-property.objective-property-size');
      assert.equal(objectivePropertyElement.find('.drop-down-toggle.selected-tag').text(), '1');
    });

    it('(not set) and all allowed values as property dropdown options', () => {
      let objectivePropertyElement = this.objectivePropertyComponent.find('.objective-property.objective-property-size');
      objectivePropertyElement.find('.drop-down-toggle.selected-tag').trigger('click');

      let propertyDropDownOptions = objectivePropertyElement.findAll('.drop-down-options li');
      assert.equal(propertyDropDownOptions.length, 5);
      assert.equal(propertyDropDownOptions.at(0).text(), '(not set)');
      assert.equal(propertyDropDownOptions.at(1).text(), 0);
      assert.equal(propertyDropDownOptions.at(2).text(), 1);
      assert.equal(propertyDropDownOptions.at(3).text(), 2);
      assert.equal(propertyDropDownOptions.at(4).text(), 3);
    });
  });

  describe('Methods', () => {
    describe('PropertyNameAsClass', () => {
      it('should convert property name to valid class name', () => {
        assert.equal('size', this.objectivePropertyComponent.vm.propertyNameAsClass());
      });

      it('should convert multi word property name to valid class name', () => {
        this.objectivePropertyComponent.setProps({objectiveProperty: {name: 'Multi word Name', allowed_values: [0, 1, 2, 3]}});
        assert.equal('multi-word-name', this.objectivePropertyComponent.vm.propertyNameAsClass());
      });

      it('should remove non word character from property name', () => {
        this.objectivePropertyComponent.setProps({objectiveProperty: {name: 'name % with $ - + special char', allowed_values: [0, 1, 2, 3]}});
        assert.equal('name-with-special-char', this.objectivePropertyComponent.vm.propertyNameAsClass());
      });
    });

    describe('UpdateProperty', () => {
      it('should set selected value', () => {
        assert.strictEqual(this.objectivePropertyComponent.vm.selected, 1);
        this.objectivePropertyComponent.vm.updateProperty(2);

        assert.strictEqual(this.objectivePropertyComponent.vm.selected, 2);
      });
    });
  });

  describe('Computed', () => {
    describe('AllowedValues', () => {
      it('should return allowedValues with (not set) option', () => {
        assert.deepEqual(this.objectivePropertyComponent.vm.allowedValues, ['(not set)', 0, 1, 2, 3]);
      });
    });

    describe('SelectedValue', () => {
      it('should return allowedValues with (not set) option', () => {
        assert.deepEqual(this.objectivePropertyComponent.vm.selectedValue, [1]);
      });
    });
  });
  describe('Watchers', () => {
    describe('Selected', () => {
      it('should emit change event with updated property', () => {
        this.objectivePropertyComponent.setData({selected:'new value'});
        let changeEvents = this.objectivePropertyComponent.emitted('change');

        assert.equal(changeEvents.length, 1);
        assert.deepEqual(changeEvents[0][0], {name:'Size', value:'new value', allowed_values:[0,1,2,3]});
      });
    });
  });
});
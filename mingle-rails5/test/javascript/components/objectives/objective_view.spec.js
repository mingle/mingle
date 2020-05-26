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
import ObjectiveView from '../../../../app/javascript/components/objectives/ObjectiveView.vue'
import Vue from 'vue'
import VModal from 'vue-js-modal'
import sinon from "sinon";
import assert from "assert";
import Vuex from "vuex";
import vSelect from 'vue-select';
Vue.component('v-select', vSelect);
import {mount, createLocalVue } from '@vue/test-utils'

const localVue = createLocalVue();
localVue.use(VModal);

let sandbox = sinon.createSandbox();
Vue.use(Vuex);

describe('ObjectiveView.vue', () => {
  let objectiveComponent, objectiveData, stubbedDispatch;
  beforeEach(function () {
    stubbedDispatch = sandbox.stub();
    objectiveData = {
      name: 'Foo', number: 1234, value_statement: 'Objective value statement', status: 'BACKLOG',
      property_definitions: {
        Size: {name: 'Size', value: 10, allowed_values: [10, 20, 30]},
        Value: {name: 'Value', value: 20, allowed_values: [10, 20, 30]}
      }
    };
    objectiveComponent = mount(ObjectiveView,
        {
          propsData: {objective: objectiveData},
          localVue: localVue,
          store: {
            state: {toggles: {readOnlyModeEnabled: false}},
            dispatch: stubbedDispatch
          }
        });
  });

  describe('Data', function () {
    it('should have heading and message for delete popup', () => {
      let expectedMessage = "CAUTION! This action is final and irrecoverable. Deleting this objective will completely erase it from your Program.";
      assert.equal(objectiveComponent.vm.deletePopupHeading, "Delete Backlog Objective");
      assert.equal(objectiveComponent.vm.deletePopupMessage, expectedMessage);
    });

  });

  describe('Renders', function () {
    it('name and number for backlog objective popup', () => {
      assert.equal('Foo', objectiveComponent.find('.view-popup-container .header .name').text());
      assert.equal('#1234', objectiveComponent.find('.view-popup-container .header .number').text().trim());
    });

    it('objective value statement', () => {
      let objectiveContent = objectiveComponent.find('.view-popup-container .objective-content');
      assert.equal('Value Statement', objectiveContent.find('.objective-value-statement-heading').text());
      assert.equal('Objective value statement', objectiveContent.find('.objective-value-statement-content').text().trim());
    });

    it('objective properties', () => {
      let objectiveContent = objectiveComponent.find('.view-popup-container .objective-properties-container');
      assert.equal('10', objectiveContent.find('.objective-property-size .selected-tag').text().trim());
      assert.equal('Size:', objectiveContent.find('.objective-property-size strong').text().trim());
      assert.equal('20', objectiveContent.find('.objective-property-value .selected-tag').text().trim());
      assert.equal('Value:', objectiveContent.find('.objective-property-value strong').text().trim());
    });

    it('delete button', () => {
      assert.equal(1, objectiveComponent.findAll('.actions .link_as_button.delete').length);
      assert.equal("DELETE", objectiveComponent.find('.actions .link_as_button.delete').text().trim());
    });

    it('plan on timeline button when status is backlog', () => {
      assert.equal(1, objectiveComponent.findAll('.actions .link_as_button.plan').length);
      assert.equal("PLAN ON TIMELINE", objectiveComponent.find('.actions .link_as_button.plan').text().trim());
    });

    it('change plan button when status is planned', () => {
      objectiveComponent.setProps({objective: Object.assign({}, objectiveData, {status: 'PLANNED'})});

      assert.equal(1, objectiveComponent.findAll('.actions .link_as_button.change-plan').length);
      assert.equal("CHANGE PLAN", objectiveComponent.find('.actions .link_as_button.change-plan').text().trim());
    });

    it('should not render buttons in readOnlyMode', () => {
      objectiveData = {
        name: 'Foo', number: 1234, value_statement: 'Objective value statement', status: 'BACKLOG',
        property_definitions: {
          Size: {name: 'Size', value: 10, allowed_values: [10, 20, 30]},
          Value: {name: 'Value', value: 20, allowed_values: [10, 20, 30]}
        }
      };
      objectiveComponent = mount(ObjectiveView,
          {
            propsData: {objective: objectiveData},
            localVue: localVue,
            store: {
              state: {toggles: {readOnlyModeEnabled: true}},
              dispatch: stubbedDispatch
            }
          });

      assert.ok(objectiveComponent.findAll('.actions').hasClass('display-off'));
    });
  });

  describe('Interactions', () => {
    describe('Click', () => {
      it('on edit button should emit edit event ', (done) => {
        objectiveComponent.vm.$on('edit', () => {
          done();
        });
        objectiveComponent.find('a.edit').trigger("click");
      });

      it('on plan on timeline should invoke planObjective', ( ) => {
        let stubbedPlanObjective = sinon.stub(objectiveComponent.vm,'planObjective');
        objectiveComponent.find('a.link_as_button.plan').trigger("click");

        assert.equal(1, stubbedPlanObjective.callCount);
        assert.ok(!stubbedPlanObjective.args[0][0]);
      });

      it('on change plan should invoke planObjective', ( ) => {
        let stubbedPlanObjective = sinon.stub(objectiveComponent.vm,'planObjective');
        objectiveComponent.setProps({objective: Object.assign({},objectiveData,{status:'PLANNED'})});
        objectiveComponent.find('a.link_as_button.change-plan').trigger("click");

        assert.equal(1, stubbedPlanObjective.callCount);
        assert.ok(stubbedPlanObjective.args[0][0]);
      });
    });

    describe('Double Click', () => {
      it('on the objective-value-statement within 1 second should trigger edit event', (done) => {
        objectiveComponent.vm.$on('edit', () => {
          done();
        });
        objectiveComponent.find('.objective-value-statement').trigger("click");
        setTimeout(() => {
          objectiveComponent.find('.objective-value-statement').trigger("click");
        }, 950);
      });

      it('on the objective name within 1 second should trigger edit event', (done) => {
        objectiveComponent.vm.$on('edit', () => {
          done();
        });
        objectiveComponent.find('.header .name').trigger("click");
        setTimeout(() => {
          objectiveComponent.find('.header .name').trigger("click");
        }, 950);

      });
    });

    describe('Invokes', function () {
      it('open confirm-delete modal', (done) => {
        let stubbedModalShow = sinon.stub(objectiveComponent.vm.$modal, 'show');
        let deleteButton = objectiveComponent.find('.actions .link_as_button.delete');

        assert.equal(0, stubbedModalShow.callCount);
        deleteButton.trigger('click');
        setTimeout(()=> {
        assert.equal(1, stubbedModalShow.callCount);
        assert.equal(1, stubbedModalShow.args[0].length);
        assert.equal('confirm-delete', stubbedModalShow.args[0][0]);
        done();
        })
      });

      it('invokes delete action on deleteObjective call', (done) => {
        let stubbedEmit = sandbox.stub(objectiveComponent.vm, '$emit');
        let promise = Promise.resolve();
        stubbedDispatch.onCall(0).returns(promise);

        objectiveComponent.vm.deleteObjective();

        assert.equal(1, stubbedDispatch.callCount);
        assert.equal(2, stubbedDispatch.args[0].length);
        assert.equal('deleteObjective', stubbedDispatch.args[0][0]);
        assert.equal(1234, stubbedDispatch.args[0][1]);

        setTimeout(() => {
          assert.equal(1, stubbedEmit.callCount);
          assert.equal(1, stubbedEmit.args[0].length);
          assert.equal('close', stubbedEmit.args[0][0]);
          done();
        });
      });

      it('invokes plan backlog objective action on plan objective call', (done) => {
        let promise = Promise.resolve();
        stubbedDispatch.onCall(0).returns(promise);

        objectiveComponent.vm.planObjective();

        assert.equal(1, stubbedDispatch.callCount);
        assert.equal(2, stubbedDispatch.args[0].length);
        assert.equal('planObjective', stubbedDispatch.args[0][0]);
        assert.equal(1234, stubbedDispatch.args[0][1]);

        setTimeout(() => {
          done();
        })
      });

      it('invokes update current backlog objective with the updated properties', ( ) => {
        let promise = Promise.resolve();
        stubbedDispatch.onCall(0).returns(promise);
        assert.deepEqual(objectiveComponent.vm.objectiveProperties, {
          Size: {name: 'Size', value: 10, allowed_values: [10, 20, 30]},
          Value: {name: 'Value', value: 20, allowed_values: [10, 20, 30]}
        });

        objectiveComponent.vm.updateObjectiveProperties({
          Size: {name: 'Size', value: 30, allowed_values: [10, 20, 30]},
          Value: {name: 'Value', value: 10, allowed_values: [10, 20, 30]}
        });

        assert.equal(stubbedDispatch.callCount, 1);
        assert.equal(stubbedDispatch.args[0].length, 2);
        assert.equal(stubbedDispatch.args[0][0], 'updateCurrentObjective');
        assert.deepEqual(stubbedDispatch.args[0][1], {
          objectiveData: {
            name: 'Foo', number: 1234, value_statement: 'Objective value statement', status: 'BACKLOG',
            property_definitions: {Size: {name: 'Size', value: 30, allowed_values:[10,20,30]}, Value: {name: 'Value', value: 10, allowed_values:[10,20,30]}}
          }
        });
      })
    });
  });

  describe('Methods', () => {
    describe('PlanObjective', () => {
      it('should dispatch change objective plan action on', (done) => {
        let promise = Promise.resolve();
        stubbedDispatch.onCall(0).returns(promise);

        objectiveComponent.vm.planObjective(true);

        assert.equal(1, stubbedDispatch.callCount);
        assert.equal(2, stubbedDispatch.args[0].length);
        assert.equal('changeObjectivePlan', stubbedDispatch.args[0][0]);
        assert.equal(1234, stubbedDispatch.args[0][1]);

        setTimeout(() => {
          done();
        })
      });
    });

  });

});

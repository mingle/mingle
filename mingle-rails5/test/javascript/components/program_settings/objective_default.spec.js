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
import ObjectiveDefault from '../../../../app/javascript/components/program_settings/ObjectiveDefault'
import assert from "assert";
import sinon from 'sinon';
import {shallow, createLocalVue} from '@vue/test-utils'

const localVue = createLocalVue();

describe('ObjectiveDefault.vue', () => {
  let objectiveDefaultComponent, storeDispatchStub, getDataStub, setDataStub, ckEditorEventBinderSpy, modeStub;
  let sandbox = sinon.createSandbox();

  beforeEach(function () {
    storeDispatchStub = sandbox.stub();
    getDataStub = sandbox.stub();
    setDataStub = sandbox.stub();
    modeStub = sandbox.stub();
    this.ckEditorInstances = {};
    CKEDITOR.instances = this.ckEditorInstances;
    ckEditorEventBinderSpy = sandbox.spy();
    this.ckEditorInstances.default_value_statement_editor = {on: ckEditorEventBinderSpy, getData: getDataStub, setData: setDataStub, mode: 'source'};

    objectiveDefaultComponent = shallow(ObjectiveDefault, {
      localVue,
      propsData: {objectiveType: {name: 'Objective', value_statement: 'Initial value statement', id: 23, property_definitions:[ {name:'Size'},  {name:'Value'}]}},
      mocks: {
        $store: {
          dispatch: storeDispatchStub
        }
      },
      stubs: {
        'property-tile': '<div class="property-tile"/>'
      }
    })
  });

  describe('Renders', function () {
    it('objective type name', () => {
      assert.equal(objectiveDefaultComponent.find('h1.objective-type-name').text(), 'Objective');
    });

    it('buttons for actions', () => {
      assert.equal(objectiveDefaultComponent.find('.actions button.save').text(), 'SAVE ALL CHANGES');
      assert.equal(objectiveDefaultComponent.find('.actions button.cancel').text(), 'CANCEL');
    });

    it('objective properties with the add property option',  () => {
      assert.ok(objectiveDefaultComponent.find('.objective-type-properties').exists());
      assert.equal(objectiveDefaultComponent.find('.objective-type-properties .add-property').text(), 'Add Property');
      assert.ok(objectiveDefaultComponent.find('.objective-type-properties .add-property .fa.fa-plus').exists());

    });

    it('objective type property definitions', () => {
      assert.equal(2, objectiveDefaultComponent.findAll('.objective-type-properties .property-tile').length)
    });
  });

  describe('Data', function () {
    it('contains ckeditor configs', () => {
      assert.equal(objectiveDefaultComponent.vm.ckEditorInstanceId, 'default_value_statement_editor');
      assert.deepEqual(objectiveDefaultComponent.vm.ckEditorConfig, {
        bodyClass: "wiki editor",
        contentsCss: [],
        resize_enabled: false,
        toolbar: [
          {
            name: "basicstyles",
            items: ["Bold", "Italic", "Underline", "Strike", "TextColor"]
          },
          {name: "styles", items: ["Format"]},
          {name: "paragraph", items: ["NumberedList", "BulletedList"]},
          {
            name: "paragraph2",
            items: ["-", "Outdent", "Indent", "-", "Blockquote"]
          },
          {name: "links", items: ["Link", "Image", "Table"]},
          {name: "insert", groups: ["insert"]},
          {name: "document", items: ["Source"]},
          {name: "tools", items: ["Maximize"]}
        ],
        height: 310,
        basicEntities: false,
        width: "100%"
      });
    });
  });

  describe('Computed property', () => {
    it('enableSave should be true when value statement has been changed', () => {
      assert.ok(!objectiveDefaultComponent.vm.enableSave);

      objectiveDefaultComponent.setData({currentObjectiveType: {name: 'Objective', value_statement: 'changed value statement'}});

      assert.ok(objectiveDefaultComponent.vm.enableSave);

      objectiveDefaultComponent.setData({currentObjectiveType: {name: 'Objective', value_statement: 'Initial value statement'}});

      assert.ok(!objectiveDefaultComponent.vm.enableSave);
    });
  });

  describe('Methods', () => {
    it('resetObjectiveType resets currentObjectiveType to initially set value and resets message', () => {
      objectiveDefaultComponent.setData({currentObjectiveType: {name: 'changed Name', value_statement: 'changed value statement'}});
      objectiveDefaultComponent.vm.resetObjectiveType();

      assert.deepEqual({name: 'Objective', value_statement: 'Initial value statement', id: 23, property_definitions:[{name:'Size'},{name:'Value'}]}, objectiveDefaultComponent.vm.currentObjectiveType);
      assert.ok(objectiveDefaultComponent.emitted().updateMessage);
      assert.equal(objectiveDefaultComponent.emitted().updateMessage.length, 1);
      assert.deepEqual(objectiveDefaultComponent.emitted().updateMessage[0][0], {});

    });

    it('updateObjectiveType should dispatch updateObjectiveType to the store and update the success message when the result is success', (done) => {
      let objectiveType = {name: 'Objective', value_statement: 'Initial value statement', id: 23};
      storeDispatchStub.returns(Promise.resolve({success: true, objectiveType: objectiveType}));
      getDataStub.returns('new value statement');

      objectiveDefaultComponent.vm.updateObjectiveType(objectiveType);
      assert.ok(objectiveDefaultComponent.vm.displayProgressBar);

      setTimeout(() => {
        assert.ok(!objectiveDefaultComponent.vm.displayProgressBar);
        assert.equal(storeDispatchStub.callCount, 1);
        assert.equal(getDataStub.callCount, 1);
        assert.equal(storeDispatchStub.args[0][1].value_statement, 'new value statement');
        assert.equal(objectiveDefaultComponent.emitted().updateMessage.length, 1);
        assert.deepEqual(objectiveDefaultComponent.emitted().updateMessage[0][0], { type: 'success', text: 'Changes have been updated successfully.' });
        done();
      });
    });

    it('updateObjectiveType should update the failure message with the error when the result is error', (done) => {
      let objectiveType = {name: 'Objective', value_statement: 'Initial value statement', id: 23};
      storeDispatchStub.returns(Promise.resolve({success: false, error: 'Something went wrong'}));

      objectiveDefaultComponent.vm.updateObjectiveType(objectiveType);

      setTimeout(() => {
        assert.equal(objectiveDefaultComponent.emitted().updateMessage.length, 1);
        assert.deepEqual(objectiveDefaultComponent.emitted().updateMessage[0][0], { type: 'error', text: 'Something went wrong' });
        done();
      });
    });

    it('modeChanged should update isSourceMode based on mode of ckEditorInstance', () => {

      objectiveDefaultComponent.setData({isSourceMode: false});

      objectiveDefaultComponent.vm.modeChanged();

      assert.ok(objectiveDefaultComponent.vm.isSourceMode);
    });
  });

  describe('Interactions', () => {
    it('Save button click should invoke updateObjectiveType', () => {
      let updateObjectiveTypeStub = sandbox.stub();
      objectiveDefaultComponent.setData({currentObjectiveType: {name: 'Objective', value_statement: 'changed value statement'}});
      objectiveDefaultComponent.setMethods({updateObjectiveType: updateObjectiveTypeStub});
      assert.equal(updateObjectiveTypeStub.callCount, 0);

      objectiveDefaultComponent.find('.actions button.save').trigger('click');

      assert.equal(updateObjectiveTypeStub.callCount, 1);
    });

    it('Cancel button click should invoke resetObjectiveType', () => {
      let resetObjectiveTypeStub = sandbox.stub();
      objectiveDefaultComponent.setMethods({resetObjectiveType: resetObjectiveTypeStub});
      assert.equal(resetObjectiveTypeStub.callCount, 0);

      objectiveDefaultComponent.find('.actions button.cancel').trigger('click');

      assert.equal(resetObjectiveTypeStub.callCount, 1);
    });
  });

  describe('LifeCycleHook', () => {
    describe('Mount', () => {
      it('should add resizeCkeditor as a listener to CKEDITOR instanceReady event', () => {
        ckEditorEventBinderSpy.reset();

        objectiveDefaultComponent = shallow(ObjectiveDefault,{
          localVue:localVue,
          propsData:{objectiveType: {name: 'Objective', value_statement: 'Initial value statement', id: 23}},
          mocks:{
            $store: {
              dispatch: storeDispatchStub
            }
          }
        });

        assert.equal(ckEditorEventBinderSpy.callCount,1);
        assert.equal(ckEditorEventBinderSpy.args[0][0], 'mode');
        assert.deepEqual(ckEditorEventBinderSpy.args[0][1], objectiveDefaultComponent.vm.modeChanged);

      });
    });
  });
});
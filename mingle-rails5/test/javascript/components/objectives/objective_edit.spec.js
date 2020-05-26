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
import ObjectiveEdit from '../../../../app/javascript/components/objectives/ObjectiveEdit.vue'
import Vue from 'vue'
import VModal from 'vue-js-modal'
import Vuex from 'vuex'
import sinon from "sinon";
import assert from "assert";
import vSelect from "vue-select";

let sandbox = sinon.createSandbox();
Vue.component(vSelect);
Vue.use(VModal, { dynamic: true });
Vue.use(Vuex);

describe('ObjectiveEdit.vue', function () {
  let ComponentConstructor, contentCss = ['https://content_1.css/', 'https://content_2.css/'];
  beforeEach(() => {
    this.storeDispatchStub = sandbox.stub();
    this.getDataStub = sandbox.stub();
    this.ckEditorReplaceSpy = sandbox.spy(CKEDITOR, 'replace');
    this.ckEditorInstances = {};
    CKEDITOR.instances = this.ckEditorInstances;
    this.ckEditorInstances.objective_value_statement_editor = { getData: this.getDataStub};

    this.objectiveData = {
      name: 'Foo',number: 1234,value_statement: 'Objective value statement',
      property_definitions: {Size: {name: 'Size', value: 1, allowed_values:[1,2,3]}, Value: {name: 'Value', value: 2, allowed_values:[1,2,3]}}
    };
    let cssStyles = contentCss.map((cssUrl) => {
      let anchor = document.createElement('a');
      anchor.href = cssUrl;
      return anchor;
    });
    sandbox.stub(document, 'querySelectorAll').withArgs('link[rel="stylesheet"]').returns(cssStyles);
    ComponentConstructor = Vue.extend(ObjectiveEdit);
    sandbox.stub(document, 'querySelector').returns({
          getStyle(style) {
            let styles = {margin: '20px', padding: '10px'};
            return styles[style];
          },
          getWidth() {
            return 40;
          }, positionedOffset() {
            return {left: 20, top: 40}
          }
        }
    );
    this.objectiveEditComponent = new ComponentConstructor({
      propsData: { objective: this.objectiveData, name: 'objective_popup' },
      store: {
        state: { foo: "bar", defaultObjectiveType: {value_statement: 'default value statement'},
                 toggles: {readOnlyModeEnabled: false}},
        dispatch: this.storeDispatchStub
      }
    }).$mount();
  });

  afterEach(() => {
    sandbox.restore();
    this.storeDispatchStub.reset();
    this.getDataStub.reset();
  });

  describe('Data', () => {
    it('should have ckeditor instance id', () => {
      assert.equal(this.objectiveEditComponent.ckEditorInstanceId, 'objective_value_statement_editor');
    });
  });

  describe('Renders', () => {
    it('progress bar when objective is saved', (done) => {
      assert.ok(!this.objectiveEditComponent.$el.querySelector('.linear-progress-bar'),'--------');
      this.objectiveEditComponent.displayProgressBar = true;
      setTimeout(() => {
        assert.ok(this.objectiveEditComponent.$el.querySelector('.linear-progress-bar'),'-------->');
        done();
      });
    });

    it('objective properties', () => {
      let objectiveContent = this.objectiveEditComponent.$el.querySelector('.edit-popup-container .objective-properties-container');
      let sizePropertyElement = objectiveContent.querySelector('.objective-property-size');
      let valuePropertyElement = objectiveContent.querySelector('.objective-property-value');

      assert.equal('1',sizePropertyElement.querySelector('.selected-tag').textContent.trim());
      assert.equal('Size:',sizePropertyElement.querySelector('.objective-property-name strong').textContent.trim());
      assert.equal('2',valuePropertyElement.querySelector('.selected-tag').textContent.trim());
      assert.equal('Value:',valuePropertyElement.querySelector('.objective-property-name strong').textContent.trim());
    });
  });

  describe('Initialization', () => {

    it('should use appropriate ckeditor config', () => {
      let expectedCkEditorConfig = {
        bodyClass: 'wiki editor',
        contentsCss: contentCss,
        resize_enabled:false,
        toolbar: [
          { name: 'basicstyles', items: ['Bold', 'Italic', 'Underline', 'Strike', 'TextColor'] },
          { name: 'styles', items: ['Format'] },
          { name: 'paragraph', items: ['NumberedList', 'BulletedList'] },
          { name: 'paragraph2', items: ['-', 'Outdent', 'Indent', '-', 'Blockquote'] },
          { name: 'links', items: ['Link', 'Image', 'Table'] },
          { name: 'insert', groups: ['insert'] },
          { name: 'document', items: ['Source'] },
          { name: 'tools', items: ['Maximize'] }
        ],
        height: 310,
        basicEntities: false,
        width: 'calc(100% - 12px)'
      };
      assert.deepEqual(this.ckEditorReplaceSpy.args[0][0], this.objectiveEditComponent.ckEditorInstanceId);
      assert.deepEqual(this.ckEditorReplaceSpy.args[0][1], expectedCkEditorConfig);
    });
  });

  it('should render progress bar when objective is saved', (done) => {
    this.payload = {scopedMessage:true, objectiveData:{}};
    this.clickEvent = {
      target: {
        className:'target class name',
        getWidth() {
          return 1;
        },
        positionedOffset(){
          return {left:2};
        },
        hasClassName(){
          'Save';
        }
      }
    };
    let destroyCkEditorWithEventStub = sandbox.stub();
    this.objectiveEditComponent.destroyCkEditorWithEvent = destroyCkEditorWithEventStub;
    this.storeDispatchStub.returns(
        Promise.resolve({ success: true, data: this.payload.objectiveData })
    );
    this.objectiveEditComponent.content = this.payload.objectiveData.value_statement;
    assert.equal(destroyCkEditorWithEventStub.callCount, 0);

    this.objectiveEditComponent.saveObjective(this.clickEvent);
    assert.ok(this.objectiveEditComponent.displayProgressBar);

    setTimeout(() => {
      assert.ok(!this.objectiveEditComponent.displayProgressBar);
      done();
    })
  });
});

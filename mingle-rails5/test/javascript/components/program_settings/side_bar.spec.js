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
import SideBar from '../../../../app/javascript/components/program_settings/SideBar'
import assert from "assert";
import sinon from "sinon";
import {shallow, createLocalVue} from '@vue/test-utils'
const localVue = createLocalVue();
let sandbox = sinon.createSandbox();


describe('SideBar.vue', () => {
  let sideBar, storeDispatchStub;
  beforeEach(function () {
    this.storeDispatchStub = sandbox.stub();
    sideBar = shallow(SideBar, {
      localVue
    });
  });

  describe('Renders', () => {
    it('should render configure properties option', () => {
      assert.equal(sideBar.find('.side-bar .side-bar-option .option-title').text(), 'CONFIGURE PROPERTIES');
      assert.ok(sideBar.find('.side-bar-option .fa.fa-angle-up').exists());
      assert.ok(!sideBar.find('.side-bar-option .fa.fa-angle-down').exists());
    });
  });

  describe('Interactions',() => {
    describe('On Click', () => {
      it('should toggle the icon and hide panel',() => {
        sideBar.find('.side-bar .side-bar-option .option').trigger('click');

        assert.ok(!sideBar.vm.openPanel);
        assert.ok(sideBar.find('.side-bar-option .fa.fa-angle-down').exists());
        assert.ok(!sideBar.find('.side-bar-option .fa.fa-angle-up').exists());
      });
    });
  });
  describe('Methods', () => {
    describe('togglePanel', () => {
      it('should toggle the openPanel', () => {
        assert.ok(sideBar.vm.openPanel);

        sideBar.vm.togglePanel();

        assert.ok(!sideBar.vm.openPanel);
      });
    });
  });
});

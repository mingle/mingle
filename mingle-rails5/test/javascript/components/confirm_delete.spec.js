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
import ConfirmDelete from '../../../app/javascript/components/ConfirmDelete.vue'
import {mount, createLocalVue} from '@vue/test-utils'
import assert from "assert";
import sinon from 'sinon'

let sandbox = sinon.createSandbox();
let localVue = createLocalVue();
describe('ConfirmDelete.vue', function () {
  beforeEach(() => {
    this.modalHideSpy = sandbox.spy();
    this.confirmDeleteComponent = mount(ConfirmDelete, {
          localVue,
          mocks: {
            $modal: {
              hide: this.modalHideSpy
            }
          }
        }
    );
  });
  afterEach(() => {
    sandbox.restore();
  });
  describe('Renders', () => {
    it('should display default heading and message', () => {
      assert.equal('Confirm Delete', this.confirmDeleteComponent.find('.header h2').text());
      assert.equal('CAUTION! This action is final and irrecoverable.', this.confirmDeleteComponent.find('.content .warning-box').text());
    });

    it('should display the custom heading and message', () => {
      this.confirmDeleteComponent.setProps({heading: 'Delete the Feature', message: 'No coming back from this!'});
      assert.equal('Delete the Feature', this.confirmDeleteComponent.find('.header h2').text());
      assert.equal('No coming back from this!', this.confirmDeleteComponent.find('.content .warning-box').text());
    });

    it('should replace ok button text', () => {
      let confirmDeleteComponent = mount(ConfirmDelete, {
            localVue,
            slots:{
              okActionText:'OK'
            },
            mocks: {
              $modal: {
                hide: this.modalHideSpy
              }
            }
          }
      );

      assert.equal('OK', confirmDeleteComponent.find('.actions .ok').text());
    });
  });
  describe('Interactions', () => {
    describe('Click', () => {
      it('should hide modal on clicking cancel', () => {
        this.confirmDeleteComponent.find('.action-bar .link_as_button').trigger('click');

        assert.equal(1, this.modalHideSpy.callCount);
        assert.equal('confirm-delete', this.modalHideSpy.args[0][0]);
      });

      it('should hide modal and emit delete event on clicking continue to delete', () => {
        this.confirmDeleteComponent.find('.ok').trigger('click');

        assert.equal(1, this.confirmDeleteComponent.emitted('delete').length);
        assert.equal(1, this.modalHideSpy.callCount);
        assert.equal('confirm-delete', this.modalHideSpy.args[0][0]);
      });
    });
  });
});

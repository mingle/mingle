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
import MessageBox from '../../../app/javascript/components/MessageBox.vue'
import Vue from 'vue'
import Vuex from 'vuex';
import assert from "assert";
Vue.use(Vuex);

describe('MessageBox.vue', () => {
  const ComponentConstructor = Vue.extend(MessageBox);
  describe('Render', function () {

    it('should not have any class or message text when no message in state', () => {
      let messageBox = new ComponentConstructor({
        store: {
          state: { message: {}}
        }
      }).$mount();
      assert.deepEqual({
        'message-box': undefined,
        'error': false,
        'success': false
      }, messageBox.classObject.messageBox);

      assert.deepEqual({
        'icon fa fa-inverse': undefined,
        'fa-check-circle': false,
        'fa-exclamation-circle': false
      }, messageBox.classObject.icon);
      assert.deepEqual(undefined, messageBox.messageText);
    });

    it('should have success classes and text for success message', () => {
      let messageBox = new ComponentConstructor({
        store: {
          state: {
            message: {
              type: 'success',
              text: 'done'
            }
          }
        }
      }).$mount();

      assert.deepEqual({
        'message-box': true,
        'error': false,
        'success':true
      }, messageBox.classObject.messageBox);

      assert.deepEqual({
        'icon fa fa-inverse': true,
        'fa-check-circle': true,
        'fa-exclamation-circle': false
      }, messageBox.classObject.icon);

      assert.deepEqual('done', messageBox.messageText);
      assert.deepEqual('done', messageBox.$el.textContent.trim());
    });

    it('should have error class and text for error message', () => {
      let messageBox = new ComponentConstructor({
        store: {
          state: {
            message: {
              type: 'error',
              text: 'failed'
            }
          }
        }
      }).$mount();
      assert.deepEqual({
        'message-box': true,
        'error': true,
        'success':false
      }, messageBox.classObject.messageBox);

      assert.deepEqual({
        'icon fa fa-inverse': true,
        'fa-check-circle': false,
        'fa-exclamation-circle': true
      }, messageBox.classObject.icon);

      assert.deepEqual('failed', messageBox.messageText);
      assert.deepEqual('failed', messageBox.$el.textContent.trim());
    });

    it('should use passed message property', () => {
      let messageBox = new ComponentConstructor({
        propsData:{message:{type:'error', text: 'Passed as property'}},
        store: {
          state: {
            message: {
              type: 'error',
              text: 'failed'
            }
          }
        }
      }).$mount();
      assert.deepEqual({
        'message-box': true,
        'error': true,
        'success':false
      }, messageBox.classObject.messageBox);

      assert.deepEqual({
        'icon fa fa-inverse': true,
        'fa-check-circle': false,
        'fa-exclamation-circle': true
      }, messageBox.classObject.icon);

      assert.equal('Passed as property', messageBox.messageText);
      assert.equal('Passed as property', messageBox.$el.textContent.trim());
    });

  });
});

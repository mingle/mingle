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
import assert from "assert";
import Tracker from '../../app/javascript/tracker'
import sinon from 'sinon';

let sandbox = sinon.createSandbox();
describe('Tracker', function () {
  let fakeMixpanel = {track(){}, identify(){}, init(){}, register(){}};
  beforeEach(function () {
    sandbox.restore();
    sandbox.spy(fakeMixpanel, 'init');
    sandbox.spy(fakeMixpanel, 'identify');
    sandbox.spy(fakeMixpanel, 'register');
    sandbox.spy(fakeMixpanel, 'track');
  });
  afterEach(function () {
    sandbox.restore();
  });

  it('tracker disabled and mixpanel not initialized when no metadata', function () {
    let tracker = new Tracker({}, fakeMixpanel);

    assert.equal(fakeMixpanel, tracker.mixpanel);
    assert.ok(!tracker.enabled);
    assert.equal(0, fakeMixpanel.init.callCount);
    assert.equal(0, fakeMixpanel.identify.callCount);
    assert.equal(0, fakeMixpanel.register.callCount);
  });

  it('tracker disabled and mixpanel not initialized when enabled false', function () {
    let tracker = new Tracker({enabled: false}, fakeMixpanel);

    assert.equal(fakeMixpanel, tracker.mixpanel);
    assert.ok(!tracker.enabled);
    assert.equal(0, fakeMixpanel.init.callCount);
    assert.equal(0, fakeMixpanel.identify.callCount);
    assert.equal(0, fakeMixpanel.register.callCount);
  });

  it('tracker initializes mixpanel when metadata set', function () {
    let tracker = new Tracker({enabled: true, api_key: '123', meta_data: 'abc', user_id: 'user-id'}, fakeMixpanel);

    assert.equal(fakeMixpanel, tracker.mixpanel);
    assert.ok(tracker.enabled);
    assert.equal(1, fakeMixpanel.init.callCount);
    assert.deepEqual(['123'], fakeMixpanel.init.args[0]);
    assert.equal(1, fakeMixpanel.identify.callCount);
    assert.deepEqual(['user-id'], fakeMixpanel.identify.args[0]);
    assert.equal(1, fakeMixpanel.register.callCount);
    assert.deepEqual(['abc'], fakeMixpanel.register.args[0]);
  });

  it('tracker calls mixpanel only when enabled', function () {
    let tracker = new Tracker({}, fakeMixpanel);
    tracker.track('abc_event', {});

    assert.equal(0, fakeMixpanel.track.callCount);

    tracker.enabled = true;
    tracker.track('abc_event', {});

    assert.equal(1, fakeMixpanel.track.callCount);
    assert.deepEqual(['abc_event', {}], fakeMixpanel.track.args[0]);
  })
});

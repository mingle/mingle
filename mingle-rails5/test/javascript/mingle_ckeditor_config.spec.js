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
import mingleCkeditorConfig from '../../app/javascript/shared/mingle_ckeditor_config'
import sinon from 'sinon';

let sandbox = sinon.createSandbox();
describe('mingleCkeditorConfig', function () {
  let documentStub;
  beforeEach(function () {
    documentStub = sandbox.stub(document, 'querySelectorAll');
    documentStub.withArgs('link[rel="stylesheet"]').returns([{href: 'http://localhost/sprockets.css'}, {href: 'nonscss'}])
  });
  afterEach(function () {
    sandbox.restore();
  });

  it('returns default config', function () {
    assert.deepEqual(mingleCkeditorConfig(), {
      bodyClass: "wiki editor",
      contentsCss: ['http://localhost/sprockets.css'],
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
      width: "calc(100% - 12px)"
    });
    assert.equal(1, documentStub.callCount);
  });

  it('returns custom config when additional properties are passed', function () {
    assert.deepEqual(mingleCkeditorConfig({resize_enabled: true}), {
      bodyClass: "wiki editor",
      contentsCss: ['http://localhost/sprockets.css'],
      resize_enabled: true,
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
      width: "calc(100% - 12px)"
    });
    assert.equal(1, documentStub.callCount);
  });
});

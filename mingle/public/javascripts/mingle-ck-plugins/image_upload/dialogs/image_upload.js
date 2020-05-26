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
CKEDITOR.dialog.add( 'imageUploadDialog', function ( editor ) {

    var dialogContents = function()  {
      return [
         {
           id: 'tab1',
           label: 'Select image to upload',
           elements: [
             {
               type: 'file',
               id: 'upload',
               style: 'height:40px',
               size: 38
             },
             {
               type: 'fileButton',
               id: 'uploadButton',
               filebrowser: 'tab1:txtUrl',
               label: 'Add',
               'for': ['tab1', 'upload']
             },
              {
                 id: 'txtUrl',
                 type: 'text',
                 inputStyle: 'display:none;',
                 onChange: function(ev) {
                    this.imageElement = editor.document.createElement( 'img' );
                    this.imageElement.setAttribute('src', $j.parseJSON(ev.data.value).path);
                    this.imageElement.setAttribute('class', 'mingle-image');
                    editor.insertElement(this.imageElement);
                    this.getDialog().hide();
                 }
               }
            ]
          }
       ];
    };

    return {
      onShow: function(e) {
        this.parts['footer'].hide();
      },
      title: 'Image Upload',
      minWidth: 400,
      minHeight: 100,
      contents: dialogContents(),
      buttons : []
    };
});

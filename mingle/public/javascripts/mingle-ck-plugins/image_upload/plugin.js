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
CKEDITOR.plugins.add('image_upload', {
  icons: 'image_upload',
  init: function(editor) {
    CKEDITOR.dialog.add( 'imageUploadDialog', this.path + 'dialogs/image_upload.js?rev=' + CKEDITOR.mingleRevision );
    
    editor.addCommand( 'imageUploadDialog', new CKEDITOR.dialogCommand( 'imageUploadDialog' ) );
    editor.ui.addButton('image_upload', {
      label: 'Insert image',
      command: 'imageUploadDialog'
    });
    
  }
  
});

function getSelectedImage( editor, element ) {
  if ( !element ) {
    var sel = editor.getSelection();
    element = ( sel.getType() == CKEDITOR.SELECTION_ELEMENT ) && sel.getSelectedElement();
  }

  if ( element && element.is( 'img' ) && !element.data( 'cke-realelement' ) && !element.isReadOnly() ) {
    return element;
  }
}

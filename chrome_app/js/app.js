/*global Store, Model, View, Controller, $$ */
(function () {
	'use strict';

	/**
	 * Sets up a brand new Todo list.
	 *
	 * @param {string} name The name of your new to do list.
	 */
	function Todo(name) {
		this.storage = new app.Store(name);
		this.model = new app.Model(this.storage);
		this.view = new app.View();
		this.controller = new app.Controller(this.model, this.view);
	}

	var todo = new Todo('todos-vanillajs');
	var DIRECTORY_LOCATION;
	
	/**
	 * Finds the model ID of the clicked DOM element
	 *
	 * @param {object} target The starting point in the DOM for it to try to find
	 * the ID of the model.
	 */
	function lookupId(target) {
		var lookup = target;

		while (lookup.nodeName !== 'LI') {
			lookup = lookup.parentNode;
		}

		return lookup.dataset.id;
	}

    function saveFile(directory, filename, data, contentType) {

	    chrome.fileSystem.getWritableEntry(directory, function(entry) {
	
	      entry.getFile(filename, {
	        create: true
	      }, function(entry) {
	        entry.createWriter(function(writer) {
	
		      writer.onwriteend = function(e) {
		        console.log('Write completed.');
		      };
		
		      writer.onerror = function(e) {
		        console.log('Write failed: ' + e.toString());
		      };
		      
	          writer.onwrite = function() {
	            writer.onwrite = null;
	            writer.truncate(writer.position);
	          };
	          
				//var text_b46data = urlsafeb64_to_b64(data);
				//var blob = b64toBlob(text_b46data, contentType);
	          
	          writer.write(blob);
	          console.log('Saved ' + filename);

	        });
	      });
	
	    });
  	};
  
	function urlsafeb64_to_b64(s) {
	  // Replace - with + and _ with /
	  return s.replace(/-/g, '+').replace(/_/g, '/');
	}
	
	function b64toBlob(b64Data, contentType, sliceSize) {
	    contentType = contentType || '';
	    sliceSize = sliceSize || 512;
	
	    var byteCharacters = atob(b64Data);
	    var byteArrays = [];
	
	    for (var offset = 0; offset < byteCharacters.length; offset += sliceSize) {
	        var slice = byteCharacters.slice(offset, offset + sliceSize);
	
	        var byteNumbers = new Array(slice.length);
	        for (var i = 0; i < slice.length; i++) {
	            byteNumbers[i] = slice.charCodeAt(i);
	        }
	
	        var byteArray = new Uint8Array(byteNumbers);
	
	        byteArrays.push(byteArray);
	    }
	
	    var blob = new Blob(byteArrays, {type: contentType});
	    return blob;
	}

	// When the enter key is pressed fire the addItem method.
	$$('#new-todo').addEventListener('keypress', function (e) {
		todo.controller.addItem(e);
	});

	// A delegation event. Will check what item was clicked whenever you click on any
	// part of a list item.
	$$('#todo-list').addEventListener('click', function (e) {
		var target = e.target;

		// If you click a destroy button
		if (target.className.indexOf('destroy') > -1) {
			todo.controller.removeItem(lookupId(target));
		}

		// If you click the checkmark
		if (target.className.indexOf('toggle') > -1) {
			todo.controller.toggleComplete(lookupId(target), target);
		}

	});

	$$('#save_location').addEventListener('click', function (e) {
		console.log('click-save');
		chrome.fileSystem.chooseEntry({type: 'openDirectory'}, function(dirEntry) {
			if (!dirEntry || !dirEntry.isDirectory) {
				console.log('invalid dir');
		        return;
		    }
		    console.log('dir entry');
			console.log(dirEntry);
			DIRECTORY_LOCATION = dirEntry;
		});
	});
	
	$$('#download').addEventListener('click', function(e) {
		console.log('click-download');
		checkAuth();
	});
	
	$$('#todo-list').addEventListener('dblclick', function (e) {
		var target = e.target;

		if (target.nodeName === 'LABEL') {
			todo.controller.editItem(lookupId(target), target);
		}
	});

	$$('#toggle-all').addEventListener('click', function (e) {
		todo.controller.toggleAll(e);
	});

	$$('#clear-completed').addEventListener('click', function () {
		todo.controller.removeCompletedItems();
	});
})();

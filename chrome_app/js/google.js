  
    var CLIENT_ID = '518366790721-81mdsr326q9uq0iq0agr9c69dgchergq.apps.googleusercontent.com';
      var SCOPES = ['https://www.googleapis.com/auth/gmail.readonly'];
      var FS;

      /**
       * Check if current user has authorized this application.
       */
      function checkAuth() {
	  	console.log('check auth');
        gapi.auth.authorize(
          {
            'client_id': CLIENT_ID,
            'scope': SCOPES.join(' '),
            'immediate': true
          }, handleAuthResult);
      }

      /**
       * Handle response from authorization server.
       *
       * @param {Object} authResult Authorization result.
       */
      function handleAuthResult(authResult) {
        var authorizeDiv = document.getElementById('authorize-div');
        if (authResult && !authResult.error) {
          // Hide auth UI, then load client library.
          authorizeDiv.style.display = 'none';
          loadGmailApi();
        } else {
          // Show auth UI, allowing the user to initiate authorization by
          // clicking authorize button.
          authorizeDiv.style.display = 'inline';
        }
      }

      /**
       * Initiate auth flow in response to user clicking authorize button.
       *
       * @param {Event} event Button click event.
       */
      function handleAuthClick(event) {
        gapi.auth.authorize(
          {client_id: CLIENT_ID, scope: SCOPES, immediate: false},
          handleAuthResult);
        return false;
      }

      /**
       * Load Gmail API client library. List labels once client library
       * is loaded.
       */
      function loadGmailApi() {
        //gapi.client.load('gmail', 'v1', listLabels);
        gapi.client.load('gmail', 'v1', bleh);
      }

	  function test_messages(result) {
		 var messageids = result;
		 
		 for (i = 0; i < messageids.length; i++) {
			 console.log("grabbed message");

			 getMessage('me', messageids[i]['id'], function(result) {
				 getAttachments('me', result, function(filename, mimeType, attachment) {
					 console.log(attachment);
					 saveFile(filename, attachment['data'], mimeType);
				 })
			 })
		 }
		  //appendPre(result);
	  }
	  
	  function getAttachments(userId, message, callback) {
		  var parts = message.payload.parts;
		  for (var i = 0; i < parts.length; i++) {
		    var part = parts[i];
		    if (part.filename && part.filename.length > 0) {
		      var attachId = part.body.attachmentId;
		      var request = gapi.client.gmail.users.messages.attachments.get({
		        'id': attachId,
		        'messageId': message.id,
		        'userId': userId
		      });
		      request.execute(function(attachment) {
		        callback(part.filename, part.mimeType, attachment);
		      });
		      break;
		    }
		  }
		}
		
	  function getMessage(userId, messageId, callback) {
		  var request = gapi.client.gmail.users.messages.get({
		    'userId': userId,
		    'id': messageId
		  });
		  request.execute(callback);
	  } 
      /**
       * Print all Labels in the authorized user's inbox. If no labels
       * are found an appropriate message is printed.
       */
      function listLabels() {
        var request = gapi.client.gmail.users.labels.list({
          'userId': 'me'
        });

        request.execute(function(resp) {
          var labels = resp.labels;
          appendPre('Labels:');

          if (labels && labels.length > 0) {
            for (i = 0; i < labels.length; i++) {
              var label = labels[i];
              appendPre(label.name);
            }
          } else {
            appendPre('No Labels found.');
          }
        });
      }

	function bleh() {
		listMessages('me','has:attachment',test_messages);
	}
	
	function listMessages(userId, query, callback) {
	  var getPageOfMessages = function(request, result) {
	    request.execute(function(resp) {
	      result = result.concat(resp.messages);
	      console.log('got here');
	      var nextPageToken = resp.nextPageToken;
	      callback(result);
	      /*
	      if (nextPageToken) {
	        request = gapi.client.gmail.users.messages.list({
	          'userId': userId,
	          'pageToken': nextPageToken,
	          'q': query
	        });
	        getPageOfMessages(request, result);
	      } else {
	        callback(result);
	      }*/
	    });
	  };
	  var initialRequest = gapi.client.gmail.users.messages.list({
	    'userId': userId,
	    'q': query
	  });
	  getPageOfMessages(initialRequest, []);
	}

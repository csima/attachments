function buttonGo() {
		$("#go-button")[0].value = "Go!";
		CANCELED = true;
		$("#go-button").toggleClass("btn-danger");
		$("#go-button").toggleClass("btn-primary");
	}
	
	function buttonCancel() {
		CANCELED = false;
		$("#go-button")[0].value = "Cancel";
		$("#go-button").toggleClass("btn-primary");
		$("#go-button").toggleClass("btn-danger");
	}
      function complete() {
	      console.log('attachments downloaded complete');
	  	  $("#go-button").prop("disabled",true);
	      save();
      }
	
	  function test() {
	  	JOBID = gon.jobid;
	  	ACCOUNT_ID = gon.account_id;
	  	IDENTITY_ID = gon.identity_id;
	  	checkStatus();
      }
      
      function checkStatus() {
	     //console.log('checking status');
		     $.ajax({url: "/status/" + ACCOUNT_ID + "/" + IDENTITY_ID, success: function(result){
		  	 	console.log(result);
		  	 	var message_completed_count = parseInt(result['message_completed_count']);
		  	 	var message_count = parseInt(result['message_count']);
		  	 	var attachment_count = parseInt(result['attachment_count']);
		  	 	var attachment_completed_count = parseInt(result['attachment_completed_count']);
		  	 	
		  	 	if(message_count > 0) {
		  	 		$('.messages').circleProgress('value',  message_completed_count / message_count);
		  	 	}
		  	 	if(attachment_count > 0) {
		  	 		$('.attachments').circleProgress('value',  attachment_completed_count / attachment_count);
		  	 	}
		  	 	$('.messages').find('strong').html(result['message_completed_count'] + "<br>of<br>" + result['message_count']);
		  	 	$('.attachments').find('strong').html(result['attachment_completed_count'] + "<br>of<br>" + result['attachment_count']);

				 if(result['message_completed_count'] == result['message_count'] &&
				 	result['attachment_completed_count'] == result['attachment_count'] && result['message_count'] > 0) {
					 	console.log('done!');
					 	complete();
				 } else {
					if (CANCELED == false) {
						setTimeout(continueExecution, 2500);
					}
				 }
			 }});
      }
      
      function continueExecution() {
	      checkStatus();
      }
      
      function cancel() {
	    $.ajax({url: "/cancel",
			success: function(result) {
				console.log('response');
			},
			error: function() {
				console.log('error');
			},
			complete: function() {
				console.log('complete');
			}
		});
      }
      function go() {
	  	query = $("#query").val();
		$.ajax({url: "/backup?query=" + query,
			success: function(result) {
				//console.log('response');
			},
			error: function() {
				//console.log('error');
			},
			complete: function() {
				test();
			}
		});
	  }
	  
	  function save() {
		// Make the message/attachments circles invisible
		$("#circles").toggle();
		// Show compression circle
		$("#circle-compress").toggle();
		$(".compress span").text('Saving');
		
		$.ajax({url: "/save_attachments",
			success: function(result) {
				console.log('response');
				JOBID = result['jobid'];
				checkSaveStatus();
			},
			error: function() {
				console.log('error');
			},
			complete: function() {
			}
		});
	  }
	  
	  function compress() {
		$('.compress').circleProgress('value', 0);
		$('.compress').find('strong').html('<i>0%</i>');
		$(".compress span").text('Compressing');
		
		$.ajax({url: "/compress",
			success: function(result) {
				console.log('response');
				JOBID = result['jobid'];
				checkCompressStatus();
			},
			error: function() {
				console.log('error');
			},
			complete: function() {
			}
		});
	  }
	  
	  function continueCompressStatus() {
		  checkCompressStatus();
	  }
	  
	  function continueSaveStatus() {
		  checkSaveStatus();
	  }
	  
	  function saveComplete() {	  
		  compress();
	  }
	  
	  function compressionComplete() {
		  $("#circle-compress").toggle();
		  $("#circles").toggle();
		  $("#download").toggle();
		  buttonGo();
		  $("#go-button").prop("disabled",false);
	  }
	  
	  function checkSaveStatus() {
		     $.ajax({url: "/save_status/" + JOBID, success: function(result){
			     	console.log(result);
			     	status = parseInt(result['count']);
			     	total = parseInt(result['total']);
			     	
			     	if(status > 0) {
				     	percent = parseInt((status / total) * 100);
				     	$('.compress').circleProgress('value', status / total);
					 	$('.compress').find('strong').html('<i>' + percent.toString() + '%</i>');
					}
			     	if(status == total) {
				     	console.log('save complete');
				     	saveComplete();
			     	} else {
				     	setTimeout(continueSaveStatus, 2500);
			     	}
			 }});
      }
      
      function checkCompressStatus() {
		     $.ajax({url: "/compress_status/" + JOBID, success: function(result){
			     	console.log(result);
			     	percent = parseInt(result['at']);
			     	
			     	if(percent > 0) {
				     	percent_display = percent / 100;
				     	$('.compress').circleProgress('value', percent_display);
					 	$('.compress').find('strong').html('<i>' + percent.toString() + '%</i>');
					}
			     	if(percent == 100) {
				     	console.log('compression complete');
				     	$("#button-href").attr("href",result['message']);
				     	compressionComplete();
			     	} else {
				     	setTimeout(continueCompressStatus, 2500);
			     	}
			 }});
      }


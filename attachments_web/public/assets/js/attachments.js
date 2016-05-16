function buttonGo() {
		log("buttonGo called");
		$("#go-button")[0].value = "Go!";
		CANCELED = true;
		$("#go-button").toggleClass("btn-danger");
		$("#go-button").toggleClass("btn-primary");
	}
	
	function buttonCancel() {
		log("buttonCancel called");
		CANCELED = false;
		$("#go-button")[0].value = "Cancel";
		$("#go-button").toggleClass("btn-primary");
		$("#go-button").toggleClass("btn-danger");
	}
      function complete() {
	      log("complete called");
	      console.log('attachments downloaded complete');
	  	  $("#go-button").prop("disabled",true);
	      save();
      }
	
	  function test() {
		log("test called");
	  	JOBID = gon.jobid;
	  	ACCOUNT_ID = gon.account_id;
	  	IDENTITY_ID = gon.identity_id;
	  	log("jobid:" + JOBID);
	  	checkStatus();
      }
      
      function checkStatus() {
	      log("checkStatus called");
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

				 if(result['message_completed_count'] == result['message_count'] && result['message_count'] > 0) {
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
	      log("continueExecution called");
	      checkStatus();
      }
      
      function cancel() {
	    log("cancel called");
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
	    log("go called");
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
		log("save called");
		// Make the message/attachments circles invisible
		$("#circles").toggle();
		// Show compression circle
		$("#circle-compress").toggle();
		$(".compress span").text('Saving');
		
		$.ajax({url: "/save_attachments",
			success: function(result) {
				console.log('response');
				JOBID = result['jobid'];
				log("save() jobid:" + JOBID);
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
		log("compress called");
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
	  
	  function log(data) {
		  console.log(data);
	  }
	  
	  function continueCompressStatus() {
		  log("continueCompressStatus called");
		  checkCompressStatus();
	  }
	  
	  function continueSaveStatus() {
		  log("continueSaveStatus called");
		  checkSaveStatus();
	  }
	  
	  function saveComplete() {	  
		  log("saveComplete called");
		  compressionComplete();
		  //compress();
	  }
	  
	  function compressionComplete() {
		  log("compressionComplete called");
		  $("#button-href").attr("href","https://s3-us-west-1.amazonaws.com/attachments.storage/" + ACCOUNT_ID + "/" + IDENTITY_ID + ".tgz");

		  $("#circle-compress").toggle();
		  $("#circles").toggle();
		  $("#download").toggle();
		  buttonGo();
		  $("#go-button").prop("disabled",false);
	  }
	  
	  function checkSaveStatus() {
		     log("checkSaveStatus called");
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
	         log("checkCompressStatus called");
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


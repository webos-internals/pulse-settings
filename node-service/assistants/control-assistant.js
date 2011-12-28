var Foundations = IMPORTS.foundations;

var PalmCall = Foundations.Comms.PalmCall;

var Future = IMPORTS.foundations.Control.Future;

var DB = Foundations.Data.DB;
	
var exec = IMPORTS.require('child_process').exec;

var DB_KIND = "org.webosinternals.pulseaudio.settings:1";

var SERVICE_ID = "org.webosinternals.pulseaudio.settings.srv";

var SERVICES_DIR = "/media/cryptofs/apps/usr/palm/services";

var ControlAssistant = function() {
};
  
ControlAssistant.prototype.run = function(future) {
	if((!this.controller.args) || (!this.controller.args.action)) {
		future.result = { returnValue: false };
	} else {
		future.nest(this.db());
		
		future.then(this, function(future) {
			var config = future.result;

			if(this.controller.args.action == "init")
				this.init(future, config, this.controller.args);
			else if(this.controller.args.action == "reset")
				this.reset(future, config, this.controller.args);
			else if(this.controller.args.action == "apply")
				this.apply(future, config, this.controller.args);
			else if(this.controller.args.action == "check")
				this.init(future, config, this.controller.args);
			else if(this.controller.args.action == "connect")
				this.connect(future, config, this.controller.args);
			else if(this.controller.args.action == "disconnect")
				this.disconnect(future, config, this.controller.args);
			else
				future.result = { returnValue: false };
		});
	}
};

//

ControlAssistant.prototype.db = function() {
	var future = DB.find({ from: DB_KIND, limit: 2 });
	
	future.then(this, function(future) {
		var result = future.result;
		
		var len = result.results ? result.results.length : 0;
		
		if (len === 0) {
			future.result = {_kind: DB_KIND, paServers: [], 
				tcpServer: false, wifiSinks: []};
		} else if (len > 1)
			throw new Error("More than 1 preferences object found");
		else
			future.result = result.results[0];
	});
		
	return future;
};

//

ControlAssistant.prototype.init = function(future, config, args) {
	var newActivity = {
		"start" : true,
		"replace": true,
		"activity": {
			"name": "wireless",
			"description" : "Wireless Network Monitor",
			"type": {"foreground": true, "persist": false},
			"trigger" : {
				"method" : "palm://com.palm.connectionmanager/getstatus",
				"params" : {'subscribe': true}
			},
			"callback" : {
				"method" : "palm://org.webosinternals.pulseaudio.settings.srv/control",
				"params" : {"action": "check"}
			}
		}
	};

	future.nest(PalmCall.call("palm://com.palm.activitymanager", "create", newActivity));

	future.then(this, function(future) {
		future.nest(PalmCall.call("palm://com.palm.connectionmanager", "getstatus", {}));
		
		future.then(this, function(future) {
			if(future.result.wifi) {
				args.wifi = future.result.wifi;

				this.check(future, config, args);
			} else {
				future.result = { returnValue: false };	
			}
		});						
	});
};

ControlAssistant.prototype.reset = function(future, config, args) {
	var cmd = "sh " + SERVICES_DIR + "/" + SERVICE_ID + "/bin/papctl.sh reset";

	exec(cmd, function(future, error, stdout, stderr) {
		if(error !== null) { 
			error.errorCode = error.code;

			future.exception = error;
		}
		else {
			future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
				'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "none"}}));
		
			future.then(this, function(future) {
				future.result = { returnValue: true };
			});
		}
	}.bind(this, future));
};

//

ControlAssistant.prototype.apply = function(future, config, args) {
	var bin = "sh " + SERVICES_DIR + "/" + SERVICE_ID + "/bin/papctl.sh";

	if(config.usbAudio) {
		var sinks = config.usbSinks.toString();	
		
		future.nest(this.execute(bin + " usbon " + sinks));
	} else {
		future.nest(this.execute(bin + " usboff"));
	}
	
	future.then(this, function(future) {
		var stdout = future.result.stdout;
	
		if((stdout) && (stdout.slice(0, 17) == "Module load error")) {
			future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
				'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "error", "reason": "usb"}}));
		} else {
			future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
				'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "none"}}));
		}
		
		future.then(this, function(future) {				
			if((!config.usbAudio) && (config.tcpServer)) {
				var method = "create";

				var activity = {
					"start" : true,
					"replace": true,
					"activity": {
						"name": "firewall",
						"description" : "Open PulseAudio Port",
						"type": {"cancellable": true, "foreground": true, "persist": false},
						"trigger" : {
							"method" : "palm://com.palm.firewall/control",
							"params" : {'subscribe': true, "rules": [
								{"protocol": "TCP", "destinationPort": 4713}]}
						},
						"callback" : {
							"method" : "palm://org.webosinternals.pulseaudio.settings.srv/control",
							"params" : {"action":"none"}
						}
					}
				};
		
				future.nest(this.execute(bin + " enable"));
			} else {
				var method = "cancel";

				var activity = { activityName: "firewall" };
		
				future.nest(this.execute(bin + " disable"));
			}
	
			future.then(this, function(future) {
				future.nest(PalmCall.call("palm://com.palm.activitymanager", method, activity));
		
				future.then(this, function(future) {
					var exception = future.exception;
		
					future.nest(PalmCall.call("palm://com.palm.connectionmanager", "getstatus", {}));

					future.then(this, function(future) {
						if(future.result.wifi) {
							args.wifi = future.result.wifi;

							this.check(future, config, args);
						} else {
							future.result = { returnValue: true };
						}
					});			
				});
			});		
		});
	});
};

ControlAssistant.prototype.check = function(future, config, args) {
	var addr = null, mode = null, sinks = null;

	if((args.wifi.state == "connected") && (args.wifi.ssid)) {
		var ssid = args.wifi.ssid.toLowerCase();

		if(!config.usbAudio) {
			for(var i = 0; i < config.paServers.length; i++) {
				if(config.paServers[i].ssid.toLowerCase() == ssid) {
					sinks = config.wifiSinks.toString();

					addr = config.paServers[i].address;

					mode = config.paServers[i].mode;
								
					break;				
				}
			}
		}
	}
	
	if((args.wifi.state == "connected") || (args.wifi.state == "disconnected")) {
		if((addr != null) && (sinks != null) && (mode == "manual")) {
			future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
				'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "manual",
					'address': addr, 'sinks': sinks}}));

			future.then(this, function(future) {
				future.result = { returnValue: true };
			});
		} else {
			args = {address: addr, sinks: sinks};

			if((addr != null) && (sinks != null)) {
				this.connect(future, config, args);
			} else {
				this.disconnect(future, config, args);
			}
		}
	} else {
		future.result = { returnValue: true };				
	}
};

//

ControlAssistant.prototype.connect = function(future, config, args) {
	if((!config.usbAudio) && (args.address) && (args.sinks)) {
		var bin = "sh " + SERVICES_DIR + "/" + SERVICE_ID + "/bin/papctl.sh";

		future.nest(this.execute(bin + " connect " + args.address + " " + args.sinks));

		future.then(this, function(future) {
			var stdout = future.result.stdout;
		
			if((stdout) && (stdout.slice(0, 16) == "Connection error")) {
				future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
					'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "error", "reason": "net"}}));
			} else if((stdout) && (stdout.slice(0, 17) == "Module load error")) {
				future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
					'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "error", "reason": "net"}}));
			} else {			
				future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
					'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "auto",
						'address': args.address, 'sinks': args.sinks}}));
			}
						
			future.then(this, function(future) {
				future.result = { returnValue: true };
			});
		});
	} else {
		future.result = { returnValue: true };
	}
};

ControlAssistant.prototype.disconnect = function(future, config, args) {
	var bin = "sh " + SERVICES_DIR + "/" + SERVICE_ID + "/bin/papctl.sh";

	future.nest(this.execute(bin + " disconnect"));

	future.then(this, function(future) {
		var stdout = future.result.stdout;

		if((args.address) && (args.sinks)) {
			future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
				'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "manual",
				'address': args.address, 'sinks': args.sinks}}));
		} else {
			future.nest(PalmCall.call("palm://com.palm.applicationManager/", "launch", {
				'id': "org.webosinternals.pulseaudio.settings", 'params': {'dashboard': "none"}}));
		}
				
		future.then(this, function(future) {
			future.result = { returnValue: true };
		});
	});
};

//

ControlAssistant.prototype.execute = function(cmd) {
	var future = new Future();
	
	exec(cmd, function(error, stdout, stderr) {
		if(error !== null) { 
			error.errorCode = error.code;
			
			future.exception = error;
		} else {
			future.result = { returnValue: true, 
				stdout: stdout, stderr: stderr};
		}
	}.bind(this));

	return future;
};


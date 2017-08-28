package pushx.awsiot.impl;

using tink.CoreApi;

class NodeAwsIotPusher<Data:{}> implements pushx.Pusher<Data> {
	
	var endpoint:String;
	var idToTopic:String->String;
	
	public function new(endpoint, ?idToTopic) {
		this.endpoint = endpoint;
		this.idToTopic = idToTopic != null ? idToTopic : function(id) return 'push/$id';
	}
	
	public function single(id:String, payload:pushx.Payload<Data>):Promise<pushx.Result> {
		return topic(idToTopic(id), payload);
	}
	
	public function multiple(ids:Array<String>, payload:pushx.Payload<Data>):Promise<pushx.Result> {
		return Promise.inParallel([for(id in ids) single(id, payload)])
			.next(function(results) {
				var errors = [];
				for(result in results) errors = errors.concat(result.errors);
				return {errors: errors};
			});
	}
	
	public function topic(topic:String, payload:pushx.Payload<Data>):Promise<pushx.Result> {
		var iotData = new IotData({endpoint: endpoint});
		return Future.async(function(cb) iotData.publish({
				topic: topic,
				payload: haxe.Json.stringify(payload),
				qos: 1,
			}, function(err, _) cb(err == null ? Success({errors: []}) : Failure(Error.withData(500, err.message, err)))));
			
	}
}

@:jsRequire('aws-sdk', 'IotData')
private extern class IotData {
	function new(config:{endpoint:String}):Void;
	function publish(params:{topic:String, payload:String, qos:Int}, cb:js.Error->Dynamic->Void):Void;
}
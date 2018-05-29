package pushx.aws.iot;

import js.aws.iotdata.IotData;

using tink.CoreApi;

private typedef Options<Data:{}> = {
	?iot:{},
	?idToTopic:String->String, 
	?jsonify:Payload<Data>->String,
}

class NodeAwsIotPusher<Data:{}> implements pushx.Pusher<Data> {
	
	var iotData:IotData;
	
	public function new(options:Options<Data>) {
		iotData = new IotData(options.iot);
		if(options.idToTopic != null) idToTopic = options.idToTopic;
		if(options.jsonify != null) jsonify = options.jsonify;
	}
	
	dynamic function idToTopic(id:String) {
		return 'push/$id';
	}
	
	dynamic function jsonify(payload:Payload<Data>) {
		return haxe.Json.stringify(payload);
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
		return Future.async(function(cb) iotData.publish({
				topic: topic,
				payload: jsonify(payload),
				qos: 1,
			}, function(err, _) cb(err == null ? Success({errors: []}) : Failure(Error.ofJsError(err)))));
			
	}
}

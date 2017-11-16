package pushx.aws.iot;

using tink.CoreApi;

class NodeAwsIotPusher<Data:{}> implements pushx.Pusher<Data> {
	
	var iotData:IotData;
	var idToTopic:String->String;
	var jsonify:Payload<Data>->String;
	
	public function new(config, ?options:{?idToTopic:String->String, ?jsonify:Payload<Data>->String}) {
		iotData = new IotData(config);
		idToTopic = options != null && options.idToTopic != null ? options.idToTopic : function(id) return 'push/$id';
		jsonify = options != null && options.jsonify != null ? options.jsonify : haxe.Json.stringify.bind(_, null, null);
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

@:jsRequire('aws-sdk', 'IotData')
private extern class IotData {
	function new(config:{endpoint:String}):Void;
	function publish(params:{topic:String, payload:String, qos:Int}, cb:js.Error->Dynamic->Void):Void;
}
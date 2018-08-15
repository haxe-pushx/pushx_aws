package pushx.aws.iot;

import js.aws.iotdata.IotData;

using tink.CoreApi;

private typedef Options<T> = {
	?iot:{},
	?idToTopic:String->String, 
	?jsonify:T->String,
}

@:build(futurize.Futurize.build())
class NodeAwsIotPusher<T> extends pushx.BasePusher<T> {
	
	var iotData:IotData;
	
	public function new(options:Options<T>) {
		iotData = new IotData(options.iot);
		if(options.idToTopic != null) idToTopic = options.idToTopic;
		if(options.jsonify != null) jsonify = options.jsonify;
	}
	
	dynamic function idToTopic(id:String) {
		return 'push/$id';
	}
	
	dynamic function jsonify(data:T) {
		return haxe.Json.stringify(data);
	}
	
	override function single(id:String, data:T):Surprise<Noise, TypedError<ErrorType>> {
		return topic(idToTopic(id), data);
	}
	
	override function topic(topic:String, data:T):Surprise<Noise, TypedError<ErrorType>> {
		return @:futurize iotData.publish({
			topic: topic,
			payload: jsonify(data),
			qos: 1,
		}, $cb1)
			.map(function(o) return switch o {
				case Success(_): Success(Noise);
				case Failure(e): Failure(wrapError(Others(e)));
			});
	}
}

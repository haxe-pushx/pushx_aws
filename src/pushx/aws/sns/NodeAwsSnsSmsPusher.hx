package pushx.aws.sns;

using tink.CoreApi;

class NodeAwsSnsSmsPusher<Data:{}> implements pushx.Pusher<Data> {
	
	var sns:SNS;
	
	public function new(?config:{}, ?options:{?toMessage:Payload<Data>->String}) {
		sns = new SNS(config);
		if(options != null && options.toMessage != null) toMessage = options.toMessage;
	}
	
	dynamic function toMessage(payload:Payload<Data>)
		return switch payload.notification {
			case null | {body: null}: '<empty>';
			case n: n.body;
		}
	
	public function single(id:String, payload:pushx.Payload<Data>):Promise<pushx.Result> {
		return Future.async(function(cb) sns.publish({
				PhoneNumber: id,
				Message: toMessage(payload),
			}, function(err, _) cb(err == null ? Success({errors: []}) : Failure(Error.ofJsError(err)))));
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
		return Future.async(function(cb) sns.publish({
				TopicArn: topic,
				Message: toMessage(payload),
			}, function(err, _) cb(err == null ? Success({errors: []}) : Failure(Error.ofJsError(err)))));
			
	}
}

@:jsRequire('aws-sdk', 'SNS')
private extern class SNS {
	function new(?config:{}):Void;
	function publish(params:{}, cb:js.Error->Dynamic->Void):Void;
}
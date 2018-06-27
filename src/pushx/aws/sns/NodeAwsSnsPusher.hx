package pushx.aws.sns;

import js.aws.sns.SNS;

using tink.CoreApi;

private typedef Options<Data:{}> = {
	application:String,
	?sns:{},
	?toMessage:Payload<Data>->String,
}

@:build(futurize.Futurize.build())
class NodeAwsSnsPusher<Data:{}> implements pushx.Pusher<Data> {
	
	var sns:SNS;
	var application:String;
	
	public function new(options:Options<Data>) {
		sns = new SNS(options.sns);
		application = options.application;
		if(options.toMessage != null) toMessage = options.toMessage;
	}
	
	dynamic function toMessage(payload:Payload<Data>)
		return switch payload.notification {
			case null | {body: null}: '<empty>';
			case n: n.body;
		}
	
	public function single(id:String, payload:pushx.Payload<Data>):Promise<pushx.Result> {
		return createEndpoint(id)
			.next(function(arn) {
				return Future.async(
					function(cb) sns.publish(
						{
							TargetArn: arn,
							Message: toMessage(payload),
							MessageStructure: 'json',
						},
						function(err, _) cb(err == null ? Success({errors: []}) : Failure(Error.ofJsError(err)))
					)
				);
			});
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
	
	function createEndpoint(token:String):Promise<String> {
		return @:futurize sns.createPlatformEndpoint({
			PlatformApplicationArn: application,
			Token: token,
			Attributes: {
				Enabled: 'true',
				Token: token,
				// CustomUserData: '',
			}
		}, $cb1).map(function(o) return switch o {
			case Success(data):
				Success(data.EndpointArn);
			case Failure(e):
				try {
					var re = ~/Endpoint (.*) already exists/g;
					if(e.data.code == 'InvalidParameter' && e.data.message.indexOf('but different attributes') != -1 && re.match(e.data.message)) {
						Success(re.matched(1));
					} else {
						Failure(e);
					}
				} catch(ex:Dynamic) {
					Failure(e);
				}
		});
	}
}

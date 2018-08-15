package pushx.aws.sns;

import js.aws.sns.SNS;

using tink.CoreApi;

private typedef Options<T> = {
	application:String,
	?sns:{},
	toMessage:T->String,
}

@:build(futurize.Futurize.build())
class NodeAwsSnsPusher<T> extends pushx.BasePusher<T> {
	
	var sns:SNS;
	var application:String;
	var toMessage:T->String;
	
	public function new(options:Options<T>) {
		sns = new SNS(options.sns);
		application = options.application;
		toMessage = options.toMessage;
	}
	
	override function single(id:String, data:T):Surprise<Noise, TypedError<ErrorType>> {
		return createEndpoint(id)
			.next(function(arn) {
				return @:futurize sns.publish({
					TargetArn: arn,
					Message: toMessage(data),
					MessageStructure: 'json',
				}, $cb1);
			})
			.map(function(o) return switch o {
				case Success(_): Success(Noise);
				case Failure(e): Failure(wrapError(e.data != null && e.data.code == 'EndpointDisabled' ? InvalidTarget : Others(e)));
			});
	}
	
	override function topic(topic:String, data:T):Surprise<Noise, TypedError<ErrorType>> {
		return @:futurize sns.createTopic({Name: topic}, $cb1)
			.next(function(o) {
				return @:futurize sns.publish({
					TopicArn: o.TopicArn,
					Message: toMessage(data),
				}, $cb1);
			})
			.map(function(o) return switch o {
				case Success(_): Success(Noise);
				case Failure(e): Failure(wrapError(Others(e)));
			});
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
		}, $cb1)
			.map(function(o) return switch o {
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
					} catch(_:Dynamic) {
						Failure(e);
					}
			});
	}
}

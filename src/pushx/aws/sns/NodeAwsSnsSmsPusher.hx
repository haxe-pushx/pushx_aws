package pushx.aws.sns;

using tink.CoreApi;

class NodeAwsSnsSmsPusher<Data:{}> extends NodeAwsSnsPusher<Data> {
	override function single(id:String, payload:pushx.Payload<Data>):Promise<pushx.Result> {
		return Future.async(function(cb) sns.publish({
				PhoneNumber: id,
				Message: toMessage(payload),
			}, function(err, _) cb(err == null ? Success({errors: []}) : Failure(Error.ofJsError(err)))));
	}
}
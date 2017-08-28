package pushx.awsiot;

import pushx.awsiot.impl.*;

typedef AwsIotPusher<Data:{}> =
#if nodejs
	NodeAwsIotPusher<Data>
#else
	#error "AWS IoT Pusher is not implemented on this target"
#end
;
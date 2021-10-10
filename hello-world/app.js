require('/mnt/efs/node/node_modules/app-module-path').addPath('/mnt/efs/node/node_modules');
var _ = require ('lodash');
const { DateTime } = require('luxon');


exports.lambdaHandler =  async function(event, context) {
    console.log("Received event: \n" + JSON.stringify(event, null, 2))
    console.log(_.chunk(['a', 'b', 'c', 'd'], 2));
    console.log(DateTime.now().setZone('America/New_York').minus({weeks:1}).endOf('day').toISO());
    return context.logStreamName
}

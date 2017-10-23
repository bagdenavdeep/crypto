var express    = require('express');
var validator  = require('express-validator');
var bodyParser = require('body-parser');
var config 	   = require('config');
var app        = express();
var port   	   = config.get("port");

app.use(bodyParser.urlencoded({ extended: true }));
app.use(validator());

require('./routes')(app);

app.listen(port, () => {
	console.log('We are live on ' + port);
});

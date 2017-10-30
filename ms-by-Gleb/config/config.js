var config = {
	API:{ 
		path: "./models/cryptobino.js",
		name: "cryptobino-server1",
		host: "127.0.0.1",
		port: "8888",
		gzip: false,
		web3: {
			provider: {
				// TODO basic authorization
				host: "http://192.168.1.8:8110"
			}
		},
		redis: {
			// TODO config
			prefix: "cb"
		}
	},
}
module.exports = config;

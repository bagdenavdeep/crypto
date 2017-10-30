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
			prefix: "cb",
		},
		contract: {
			path: "./contracts/b.json",
			address: "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe",
		}
	},
}
module.exports = config;

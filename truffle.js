module.exports = {
	networks: {
		development: {
			host: "localhost",
			port: 8545,
			network_id: "*" // Match any network id,
			gas: 4712388 // Gas limit used for deploys
		},
		rinkeby: {
			host: "localhost", // Connect to geth on the specified
			port: 8545,
			from: "0xC82d0554D5ee7AC2e2eb1FBE0400De426DD2CFC5", // default address to use for any transaction Truffle makes during migrations
			network_id: 4,
			gas: 4712388 // Gas limit used for deploys
		}
	}
};

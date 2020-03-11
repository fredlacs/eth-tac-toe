const TicTacToe = artifacts.require("TicTacToe");

contract('TicTacToe', function(accounts) {
    let contract;
    let player1 = accounts[0]
    let player2 = accounts[1]

    before( async () => {
        contract = await TicTacToe.new();
    })

    describe("Constructor", () => {
        it("Create match and update state", async () => {
            const receipt = await contract.startMatch(player2, 200, {from: player1})
            const matchId = receipt.logs[0].args.matchId
            assert.equal(matchId, "0xa3f4c6b921ab21c7497ffe398bfb33f3b37595b6946f3fa1296565f9a8898692")

            let nonce = 0
            let gameStatus = 0
            let board = []

            let signature1 = ""
            let signature2 = ""
        })
    })

        
})
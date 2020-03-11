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
            let board = [1, 0, 0, 0, 0, 0, 0, 0, 0]

            let signature1 = "0xfc535646a278f7628b6d2744298ae450c8b56e8d74622004829fd74e623529851c85ac16e8daac9dbfadd6da8ac0ed325a7c415652ad82bc0647bc684651df591b"
            let signature2 = "0x8abe6aaba840e5d9bf9a2e5e3c858b2240ff086899b34f41bd2014016e42b4d61c751a71cffb81594dda6bbcde56bbee61cc36e9e1c90c92d16279f5a83a16931b"

            const result = await contract.sendStateUpdate(matchId, board, gameStatus, nonce, signature1, signature2, {from: player1})
            console.log(result)

            assert.equal(nonce, 0)
        })
    })

        
})
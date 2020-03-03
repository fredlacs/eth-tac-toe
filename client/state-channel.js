
export function sign(state, callback) {
    // change this once state message is set
    let msg = web3.sha3(state.toString())
    let from = web3.eth.accounts[0]

    web3.eth.sign(from, msg, function(err, res) {
        if(err) console.log(err)
        else callback(res)
    })
}

/*
function submitState(state) {
    params: [{
        "from": "0xb60e8dd61c5d32be8058bb8eb970870f07233155",
        "to": "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
        "gas": "0x76c0", // 30400
        "gasPrice": "0x9184e72a000", // 10000000000000
        "value": "0x9184e72a", // 2441406250
        "data": "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"
      }]
      
      ethereum.sendAsync({
        method: 'eth_sendTransaction',
        params: params,
        from: accounts[0], // Provide the user's account to use.
      }, (err, response) => {
        if (err) {
          // Handle the error
        } else {
          // This always returns a JSON RPC response object.
          // The result varies by method, per the JSON RPC API.
          // For example, this method will return a transaction hash on success.
          const result = response.result
        }
      })
}
*/

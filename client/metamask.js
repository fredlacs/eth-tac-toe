if (typeof window.ethereum !== 'undefined') {
    const provider = window.ethereum
  
    if(provider.isMetaMask) {
        
        ethereum.enable()
        .then(function (accounts) {
            if(provider.networkVersion == 1) {
                alert("This is not ready for mainnet. Please connect metamask to testnet")
            }
        })
        .catch(function (error) {
            // Handle error. Likely the user rejected the login
            console.error(error)
        })
  
    } else {
        // user might be using some kind of eth browser
        alert("Please use Metamask")
    }
} else {
    alert("Please install Metamask")
}

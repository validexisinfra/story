# Story

# Story Setup & Upgrade Scripts
A collection of automated scripts for setting up and upgrading Story nodes on both Testnet (aeneid) and Mainnet.

---

## 🌟 Testnet Setup (aeneid)

### ⚙️ Validator Node Setup  
Set up a Validator Node on the Aeneid testnet to securely participate in block validation.

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/Story/main/install_testnet.sh)
~~~

---

## 🌟 Mainnet Setup

### ⚙️ Validator Node Setup  
Deploy a Validator Node on Story Mainnet and contribute to network security.

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/Story/main/install.sh)
~~~

---

## 🔄 Upgrade Scripts

### 🔄 Upgrade Testnet  
Update your Story on the testnet to the latest version.

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/Story/main/upgrade_testnet.sh)
~~~

---

### 🔄 Upgrade Mainnet  
Keep your Story on the mainnet up-to-date.

~~~bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/Story/main/upgrade_mainnet.sh)
~~~

---

### 📌 How to Use  
Copy the relevant command for your setup.  

Paste it into your Linux terminal and execute.  

Follow on-screen instructions.  

💡 Tip: Always ensure your system meets the required dependencies before running scripts.

---

##  🔗 Story Network Endpoints 

###  📀 Mainnet

####  🌌 Cosmos
-  **API**: [`https://api-story-mainnet.validexis.com`](https://api-story-mainnet.validexis.com)  
-  **RPC**: [`https://rpc-story-mainnet.validexis.com`](https://rpc-story-mainnet.validexis.com)
-  **WebSocket**: [`wss://rpc-story-mainnet.validexis.com/websocket`](wss://rpc-story-mainnet.validexis.com/websocket)
  
####  🧩 Ethereum Virtual Machine (EVM)  
-  **JSON-RPC**:  [`https://evm-story-mainnet.validexis.com:443`](https://evm-story-mainnet.validexis.com:443)
-  **WebSocket**: [`wss://wss-story-mainnet-wss.validexis.com:443`](wss://wss-story-mainnet-wss.validexis.com:443)

####  📘 AddrBook (auto-updated every 1h)
Download the latest address book for faster peer discovery:
```bash
wget -O $HOME/.story/story/config/addrbook.json https://mainnets1.validexis.com/story/addrbook.json
```

### 🔌 Peers & Seeds

### 📡 Persistent Peer
~~~bash
607f17f8be461d5b204361df8d18a06d2c7b66c9@story-mainnet-peer.validexis.com:35656
~~~

### 🌱 Seed Node
~~~bash
249de5c0085eb175da6ad7031f96bfc3ad751e33@story-mainnet-seed.validexis.com:35656
~~~

---

### 🧪 Testnet

####  🌌 Cosmos
-  **API**: [`https://api-story-testnet.validexis.com`](https://api-story-testnet.validexis.com)  
-  **RPC**: [`https://rpc-story-testnet.validexis.com`](https://rpc-story-testnet.validexis.com)
-  **WebSocket**: [`wss://rpc-story-testnet.validexis.com/websocket`](wss://rpc-story-testnet.validexis.com/websocket)
  
####  🧩 Ethereum Virtual Machine (EVM)  
-  **JSON-RPC**:  [`https://evm-story-testnet.validexis.com:443`](https://evm-story-testnet.validexis.com:443)
-  **WebSocket**: [`wss://wss-story-testnet-wss.validexis.com:443`](wss://wss-story-testnet-wss.validexis.com:443)

####  📘 AddrBook (auto-updated every 1h)
Download the latest address book for faster peer discovery:
```bash
wget -O $HOME/.story/story/config/addrbook.json https://testnets1.validexis.com/story/addrbook.json
```

### 🔌 Peers & Seeds

### 📡 Persistent Peer
~~~bash
5713c7da1e80c938643ea4aa99957bb0aadde9c1@story-testnet-peer.validexis.com:36656
~~~

### 🌱 Seed Node
~~~bash
dfb96be7e47cd76762c1dd45a5f76e536be47faa@story-testnet-seed.validexis.com:36656
~~~

---

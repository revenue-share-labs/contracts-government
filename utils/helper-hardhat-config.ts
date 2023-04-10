export interface networkConfigItem {
  ethUsdPriceFeed?: string
  blockConfirmations?: number
}

export interface networkConfigInfo {
  [key: string]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
  localhost: {},
  hardhat: {},
  goerli: {
    blockConfirmations: Number(6)
  },
}

export const developmentChains = ["hardhat", "localhost", "goerli", "bsc"]
export const proposalsFile = "proposals.json"

// Governor Values
export const QUORUM_PERCENTAGE = 4 // Need 4% of voters to pass
export const MIN_DELAY = 3600 // 1 hour - after a vote passes, you have 1 hour before you can enact
// export const VOTING_PERIOD = 45818 // 1 week - how long the vote lasts. This is pretty long even for local tests
export const VOTING_PERIOD = 5 // blocks
export const VOTING_DELAY = 1 // 1 Block - How many blocks till a proposal vote becomes active
export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"

export const NEW_STORE_VALUE = 77
export const FUNC = "store"
export const PROPOSAL_DESCRIPTION = "Proposal #1 77 in the Box!"

export const NEW_NFT_OWNER = "0x3604226674A32B125444189D21A51377ab0173d1"
export const SENDED_AMOUNT = "100000000000"
export const NFT_NUMBER = "0"
export const NFT_FUNC = "safeTransferFrom"
export const NFT_PROPOSAL_DESCRIPTION = "Proposal #2 New owner 0x3604226674A32B125444189D21A51377ab0173d1 with balance 100000000000!"

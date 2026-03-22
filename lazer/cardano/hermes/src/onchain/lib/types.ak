use aiken/crypto.{VerificationKeyHash}

pub type PosixTime =
  Int

pub type Direction {
  Up
  Down
}

pub type Operation {
  Buy
  Sell
}

pub type Price {
  numerator: Int,
  denominator: Int,
}

pub type OrderDatum {
  direction: Direction,
  operation: Operation,
  price: Price,
  owner: VerificationKeyHash,
}

pub type OrderRedeemer {
  Cancel
  Match
  Fill
}

pub type OrderMintRedeemer {
  Mint
  Burn
}

pub type MarketDatum {
  start_price: Price,
  end_price: Option<Price>,
  ramaining_shares: Int,
}

pub type MarketRedeemer {
  RecordFinalPrice
  ClaimWinnings
  ClaimLosings
  CloseMarket
}

pub type MarketMintRedeemer {
  MintControlToken
  BurnControlToken
  MintPositionToken(Direction)
  BurnPositionToken(Direction)
}

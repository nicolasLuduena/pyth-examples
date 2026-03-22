use aiken/collection/dict.{to_pairs}
use aiken/collection/list as list
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{
  PolicyId, Value, from_asset, from_lovelace, match, merge, negate, quantity_of,
  tokens,
}
use cardano/transaction.{InlineDatum, Output, Transaction}
use contants.{down_tn, up_tn}
use hermes_types.{Buy, Direction, Down, Operation, OrderDatum, Price, Sell, Up}

pub fn validate_cancel(
  own_datum: OrderDatum,
  own_policy: PolicyId,
  own_value: Value,
  tx: Transaction,
) -> Bool {
  let Transaction { extra_signatories, mint, .. } = tx

  let neg_control_token = tokens(negate(own_value), own_policy)

  and {
    // Owner is signing the transaction
    list.has(extra_signatories, own_datum.owner),
    // Control token is burnt
    match(mint, neg_control_token, ==),
  }
}

pub fn validate_match() -> Bool {
  todo
}

pub fn validate_fill(
  own_datum: OrderDatum,
  own_value: Value,
  own_policy: PolicyId,
  filled_amount: Int,
  position_token_policy: PolicyId,
  tx: Transaction,
) -> Bool {
  let Transaction { outputs, mint, .. } = tx

  expect [Pair(control_token_tn, 1)] =
    tokens(own_value, own_policy) |> to_pairs()

  let OrderDatum {
    direction: i_d_direction,
    operation: i_d_operation,
    price: i_d_price,
    owner: i_d_owner,
    expected_tokens: i_d_expected_tokens,
  } = own_datum

  let expected_owner_value =
    calculate_asked_tokens(
      i_d_direction,
      i_d_operation,
      i_d_price,
      filled_amount,
      position_token_policy,
    )

  // Owner expected output
  //   addr: owner
  //   Value: filled tokens
  let owner_output_found =
    list.any(
      outputs,
      fn(Output { address: o_addr, value: o_val, .. }) {
        o_addr.payment_credential == VerificationKey(i_d_owner) && match(
          o_val,
          expected_owner_value,
          >=,
        )
      },
    )

  let continuing_order_ok = or {
      and {
        // Is complete fill
        i_d_expected_tokens == filled_amount,
        // Control token is burnt
        quantity_of(mint, own_policy, control_token_tn) == -1,
      },
      {
        let expected_datum =
          OrderDatum {
            ..own_datum,
            expected_tokens: i_d_expected_tokens - filled_amount,
          }
        let expected_datum_data: Data = expected_datum

        let offered_tokens =
          calculate_offered_tokens(
            i_d_direction,
            i_d_operation,
            i_d_price,
            filled_amount,
            position_token_policy,
          )

        let expected_order_value = merge(own_value, negate(offered_tokens))

        // Continuing order
        //   addr: own_policy
        //   Value: own_value - filled_amount
        //   Datum: expected_datum
        list.any(
          outputs,
          fn(Output { address: o_addr, value: o_val, datum: o_datum, .. }) {
            if o_addr.payment_credential == Script(own_policy) {
              expect InlineDatum(o_dat) = o_datum

              and {
                match(o_val, expected_order_value, >=),
                o_dat == expected_datum_data,
              }
            } else {
              False
            }
          },
        )
      },
    }

  and {
    owner_output_found,
    continuing_order_ok,
  }
}

//-------------------------
// LIBRARY
//-------------------------

pub fn calculate_asked_tokens(
  dir: Direction,
  op: Operation,
  price: Price,
  filled_amount: Int,
  position_token_policy: PolicyId,
) {
  when op is {
    Buy ->
      when dir is {
        Up -> from_asset(position_token_policy, up_tn, filled_amount)
        Down -> from_asset(position_token_policy, down_tn, filled_amount)
      }
    Sell -> from_lovelace(filled_amount * price.numerator / price.denominator)
  }
}

pub fn calculate_offered_tokens(
  dir: Direction,
  op: Operation,
  price: Price,
  filled_amount: Int,
  position_token_policy: PolicyId,
) {
  when op is {
    Buy -> from_lovelace(filled_amount * price.numerator / price.denominator)
    Sell ->
      when dir is {
        Up -> from_asset(position_token_policy, up_tn, filled_amount)
        Down -> from_asset(position_token_policy, down_tn, filled_amount)
      }
  }
}

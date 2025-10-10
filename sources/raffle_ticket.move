module suipin::raffle_ticket;

// === Imports ===

use sui::{
    balance::{Balance},
    coin::{Coin},
    derived_object::{Self},
    sui::SUI,
};

// === Structs ===

public struct RaffleTicket has key, store {
  id: UID,
  raffle_id: ID,
}

public(package) fun new(
  raffle_uid_mut: &mut UID,
  ctx: &TxContext,
): RaffleTicket {
  RaffleTicket {
    id: derived_object::claim(raffle_uid_mut, ctx.sender()),
    raffle_id: raffle_uid_mut.to_inner(),
  }
}

public fun destroy(self: RaffleTicket, ctx: &TxContext) {
    let RaffleTicket { id, raffle_id: _ } = self;
    id.delete();
}

public fun id(self: &RaffleTicket): ID {
  self.id.to_inner()
}

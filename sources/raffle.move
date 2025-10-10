module suipin::raffle;

// === Imports ===

use std::{
    string::{String},
};
use sui::{
    clock::{Clock},
    event,
    balance::{Balance},
    coin::{Coin},
    random::Random,
    table_vec::{Self, TableVec},
};
use suipin::raffle_ticket::{Self, RaffleTicket};

// === Errors ===

const ENotOwner: u64 = 0;
const ENotEnoughTickets: u64 = 1;
const EWrongRaffleTicket: u64 = 2;
const EInvalidState: u64 = 3;

// === Structs ===

public struct Raffle<phantom Currency> has key {
    id: UID,
    state: RaffleState,
    title: String,
    min_ticket_count: u64,
    tickets: TableVec<ID>,
    reward: Balance<Currency>,
}

public enum RaffleState has copy, drop, store {
    Active,
    TicketSelected(ID),
    RewardClaimed(address, ID, u64),
}

public struct RaffleAdminCap has key, store {
    id: UID,
    raffle_id: ID
}

// === Events ===

public struct RaffleTicketSelectedEvent has copy, drop {
    raffle_id: ID,
    ticket_id: ID,
}

// === Public Functions ===

public fun new<T>(
    title: String,
    min_ticket_count: u64,
    reward_coin: Coin<T>,
    ctx: &mut TxContext
): (Raffle<T>, RaffleAdminCap) {
    let raffle = Raffle {
        id: object::new(ctx),
        state: RaffleState::Active,
        title,
        min_ticket_count,
        tickets: table_vec::empty(ctx),
        reward: reward_coin.into_balance(),
    };

    let raffle_admin_cap = RaffleAdminCap {
        id: object::new(ctx),
        raffle_id: raffle.id.to_inner()
    };

    (raffle, raffle_admin_cap)
}

public fun join<Currency>(
    self: &mut Raffle<Currency>,
    ctx: &mut TxContext
): RaffleTicket {
    match (self.state) {
        RaffleState::Active => {
            let ticket = raffle_ticket::new(&mut self.id, ctx);
            self.tickets.push_back(ticket.id());
            ticket
        },
        _ => abort EInvalidState,
    }
}

public fun claim_reward<Currency>(
    self: &mut Raffle<Currency>,
    ticket: RaffleTicket,
    clock: &Clock,
    ctx: &mut TxContext
): Coin<Currency> {
    match (self.state) {
        RaffleState::TicketSelected(ticket_id) => {
            assert!(ticket_id == ticket.id(), EWrongRaffleTicket);

            self.state = RaffleState::RewardClaimed(ctx.sender(), ticket.id(), clock.timestamp_ms());
            
            ticket.destroy(ctx);
            self.reward.withdraw_all().into_coin(ctx)
        },
        _ => abort EInvalidState,
    }
}

entry fun select_winner<Currency>(
    self: &mut Raffle<Currency>,
    cap: &RaffleAdminCap,
    random: &Random,
    ctx: &mut TxContext
) {
    match (self.state) {
        RaffleState::Active => {
            assert!(self.id.to_inner() == cap.raffle_id, ENotOwner);

            let ticket_count = self.tickets.length();
            assert!(ticket_count >= self.min_ticket_count, ENotEnoughTickets);

            let mut rg = random.new_generator(ctx);
            let idx = rg.generate_u64_in_range(0, ticket_count - 1);
            let ticket_id = self.tickets.swap_remove(idx);

            self.state = RaffleState::TicketSelected(ticket_id);

            event::emit(RaffleTicketSelectedEvent {
                raffle_id: self.id.to_inner(),
                ticket_id,
            });
        },
        _ => abort EInvalidState,
    }
}

public fun share<Currency>(self: Raffle<Currency>) {
    transfer::share_object(self);
}

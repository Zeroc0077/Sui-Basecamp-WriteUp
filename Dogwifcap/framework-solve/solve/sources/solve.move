module solution::dogwifcap_solution {
    use sui::tx_context::{Self, TxContext};
    use challenge::dogwifcap;

    public entry fun solve(status: &mut dogwifcap::Challenge, ctx: &mut TxContext) {
        let cap = dogwifcap::new_challenge(ctx);
        dogwifcap::level_up(&cap, status);
        sui::transfer::public_transfer(cap, tx_context::sender(ctx));
    }
}

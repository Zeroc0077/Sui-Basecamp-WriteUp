module challenge::dogwifcap{
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    // [*] Error Codes
    const ERR_INVALID_CODE : u64 = 31337;

    // [*] Structs
    struct Challenge has key {
        id: UID,
        level: u8,
        solved: bool
    }
    struct ChallengeCap has key, store {
        id: UID,
        for: address
    }

    // [*] Module initializer
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Challenge {
            id: object::new(ctx),
            level: 0,
            solved: false
        })
    }

    // [*] Public functions
    public fun new_challenge(ctx: &mut TxContext): ChallengeCap {
        let challenge = Challenge {
            id: object::new(ctx),
            level: 0,
            solved: false
        };

        let cap = ChallengeCap {
            id: object::new(ctx),
            for: object::id_address(&challenge)
        };

        transfer::share_object(challenge);
        cap
    }

    public fun level_up(cap: &ChallengeCap, challenge: &mut Challenge) {
        assert!(cap.for != object::id_address(challenge), 0);

        challenge.level = challenge.level + 1;
        challenge.solved = true;
    }

    public entry fun is_solved(challenge: &mut Challenge) {
        assert!(challenge.solved == true, ERR_INVALID_CODE);
    }
}

module challenge::pow {

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::transfer;

    const ENotSolved: u64 = 1234;

    struct Challenge has key {
        id: UID,
        is_solved: bool
    }

    struct ChallengeProof {
        data: vector<u8>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Challenge {
            id: object::new(ctx),
            is_solved: false
        })
    }

    public fun prepare_proof(data: vector<u8>): ChallengeProof {
        ChallengeProof {
            data
        }
    }

    public fun resolve_proof(challenge: &mut Challenge, proof: ChallengeProof) {
        let ChallengeProof { data } = proof;
        assert!(sui::object::id_to_address(&sui::object::uid_to_inner(&challenge.id)) 
                    == 
                sui::address::from_bytes(data), ENotSolved);

        challenge.is_solved = true;
    }


    public fun is_solved(challenge: &Challenge) {
        assert!(challenge.is_solved , ENotSolved);
    }
    
    public fun solved_bool(challenge: &Challenge): bool{
       challenge.is_solved
    }

}